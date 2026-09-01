import 'dart:io';

/// Tear-down helper: deletes a test's temp directory, tolerating the Windows
/// failures a POSIX run never sees — errno 32 ("in use by another process":
/// an open handle, POSIX happily unlinks open files) and errno 145
/// ("directory not empty": a racing write landed between the recursive
/// delete's enumeration and its rmdir).
///
/// Best-effort by design: transient races clear within the retries, but a
/// handle the app holds for the whole process lifetime (full-app boots in
/// widget tests keep some files open) cannot be deleted on Windows until
/// exit. Scratch-space cleanup asserts nothing about the product, so after
/// the retries the leftover dir is abandoned to the OS temp cleaner rather
/// than failing the test.
///
/// Blocking [sleep] on purpose: it behaves identically under fake-async test
/// zones, where an awaited Future.delayed would hang forever.
void deleteTempDirSync(Directory dir) {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      sleep(const Duration(milliseconds: 50));
    }
  }
}
