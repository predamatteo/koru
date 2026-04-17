enum KoruFont {
  system(id: 0, family: null, displayName: 'System'),
  goldman(id: 1, family: 'Goldman', displayName: 'Goldman'),
  orbitron(id: 2, family: 'Orbitron', displayName: 'Orbitron'),
  architectsDaughter(id: 3, family: 'ArchitectsDaughter', displayName: 'Architects Daughter'),
  openDyslexic(id: 4, family: 'OpenDyslexic', displayName: 'OpenDyslexic');

  const KoruFont({required this.id, required this.family, required this.displayName});

  final int id;
  final String? family;
  final String displayName;

  static KoruFont fromId(int id) =>
      KoruFont.values.firstWhere((f) => f.id == id, orElse: () => KoruFont.system);
}
