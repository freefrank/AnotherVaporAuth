/// Build-time distribution channel, set via `--dart-define=AVA_CHANNEL=play|cn`
/// (must match the Android `--flavor`).
enum AvaChannel { play, cn }

/// Unrecognized or missing values resolve to [AvaChannel.cn]: the minimal
/// dependency surface, so a build that forgot the define can never expose
/// Play-only surfaces (ads, billing, Google sign-in) by accident.
AvaChannel parseAvaChannel(String raw) =>
    raw == 'play' ? AvaChannel.play : AvaChannel.cn;

const String _rawChannel =
    String.fromEnvironment('AVA_CHANNEL', defaultValue: 'cn');

const AvaChannel avaChannel =
    _rawChannel == 'play' ? AvaChannel.play : AvaChannel.cn;
