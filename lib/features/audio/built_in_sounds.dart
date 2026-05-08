class BuiltInSound {
  final String asset; // e.g. 'sounds/ping_simple.wav'
  final String name;  // Hebrew display name

  const BuiltInSound({required this.asset, required this.name});
}

const builtInSounds = [
  BuiltInSound(asset: 'sounds/ping_simple.wav',  name: 'צלצול פשוט'),
  BuiltInSound(asset: 'sounds/ping_double.wav',  name: 'צלצול כפול'),
  BuiltInSound(asset: 'sounds/ping_triple.wav',  name: 'צלצול משולש'),
  BuiltInSound(asset: 'sounds/chime_soft.wav',   name: 'פעמון עדין'),
  BuiltInSound(asset: 'sounds/chime_bell.wav',   name: 'פעמון'),
  BuiltInSound(asset: 'sounds/alert_low.wav',    name: 'התראה נמוכה'),
  BuiltInSound(asset: 'sounds/alert_medium.wav', name: 'התראה בינונית'),
  BuiltInSound(asset: 'sounds/alert_high.wav',   name: 'התראה גבוהה'),
  BuiltInSound(asset: 'sounds/tone_rise.wav',    name: 'טון עולה'),
  BuiltInSound(asset: 'sounds/tone_fall.wav',    name: 'טון יורד'),
  BuiltInSound(asset: 'sounds/tone_wave.wav',    name: 'גלי'),
  BuiltInSound(asset: 'sounds/beep_quick.wav',   name: 'צפצוף מהיר'),
  BuiltInSound(asset: 'sounds/beep_long.wav',    name: 'צפצוף ארוך'),
  BuiltInSound(asset: 'sounds/melody_1.wav',     name: 'מנגינה 1'),
  BuiltInSound(asset: 'sounds/melody_2.wav',     name: 'מנגינה 2'),
  BuiltInSound(asset: 'sounds/xylophone.wav',    name: 'קסילופון'),
  BuiltInSound(asset: 'sounds/piano.wav',        name: 'פסנתר'),
  BuiltInSound(asset: 'sounds/gentle.wav',       name: 'עדין'),
  BuiltInSound(asset: 'sounds/morning.wav',      name: 'בוקר'),
  BuiltInSound(asset: 'sounds/urgent.wav',       name: 'דחוף'),
];

/// Returns Hebrew name for a given soundPath (asset key or file path).
String soundDisplayName(String? soundPath) {
  if (soundPath == null || soundPath.isEmpty) return 'ברירת מחדל';
  final match = builtInSounds.where((s) => s.asset == soundPath).firstOrNull;
  if (match != null) return match.name;
  return soundPath.split(RegExp(r'[/\\]')).last;
}
