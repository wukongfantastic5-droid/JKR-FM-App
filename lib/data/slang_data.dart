class SlangEntry {
  String standard;
  String kelantan;
  String phonetic;

  SlangEntry({
    this.standard = '',
    this.kelantan = '',
    this.phonetic = '',
  });

  Map<String, dynamic> toJson() => {
    'standard': standard,
    'kelantan': kelantan,
    'phonetic': phonetic,
  };

  factory SlangEntry.fromJson(Map<String, dynamic> json) => SlangEntry(
    standard: json['standard'] as String? ?? '',
    kelantan: json['kelantan'] as String? ?? '',
    phonetic: json['phonetic'] as String? ?? '',
  );
}

List<SlangEntry> defaultSlangEntries() => [
  SlangEntry(standard: 'aku', kelantan: 'saye', phonetic: 'saye'),
  SlangEntry(standard: 'saya', kelantan: 'awa', phonetic: 'awa'),
  SlangEntry(standard: 'kamu', kelantan: 'demo', phonetic: 'demo'),
  SlangEntry(standard: 'awak', kelantan: 'mung', phonetic: 'mung'),
  SlangEntry(standard: 'dia', kelantan: 'dio', phonetic: 'dio'),
  SlangEntry(standard: 'mereka', kelantan: 'depa', phonetic: 'depa'),
  SlangEntry(standard: 'tidak', kelantan: 'tok', phonetic: 'tok'),
  SlangEntry(standard: 'boleh', kelantan: 'bo', phonetic: 'bo'),
  SlangEntry(standard: 'saja', kelantan: 'je', phonetic: 'je'),
  SlangEntry(standard: 'sangat', kelantan: 'gheng', phonetic: 'gheng'),
  SlangEntry(standard: 'hendak', kelantan: 'nak', phonetic: 'nak'),
  SlangEntry(standard: 'kenapa', kelantan: 'sbb', phonetic: 's-b-b'),
  SlangEntry(standard: 'pergi', kelantan: 'gi', phonetic: 'gi'),
  SlangEntry(standard: 'datang', kelantan: 'tiga', phonetic: 'tiga'),
  SlangEntry(standard: 'buat', kelantan: 'bb', phonetic: 'b-b'),
  SlangEntry(standard: 'hendak', kelantan: 'mo', phonetic: 'mo'),
  SlangEntry(standard: 'itu', kelantan: 'tu', phonetic: 'tu'),
  SlangEntry(standard: 'ini', kelantan: 'ni', phonetic: 'ni'),
  SlangEntry(standard: 'yang', kelantan: 'hok', phonetic: 'hok'),
  SlangEntry(standard: 'sedang', kelantan: 'dok', phonetic: 'dok'),
  SlangEntry(standard: 'telah', kelantan: 'dah', phonetic: 'dah'),
  SlangEntry(standard: 'juga', kelantan: 'ggak', phonetic: 'g-gak'),
  SlangEntry(standard: 'betul', kelantan: 'ceh', phonetic: 'ceh'),
  SlangEntry(standard: 'tolong', kelantan: 'tok', phonetic: 'tok-ong'),
  SlangEntry(standard: 'lihat', kelantan: 'tengok', phonetic: 'tengok'),
  SlangEntry(standard: 'makan', kelantan: 'make', phonetic: 'make'),
  SlangEntry(standard: 'minum', kelantan: 'minum', phonetic: 'minum'),
  SlangEntry(standard: 'baru', kelantan: 'baru', phonetic: 'baru'),
  SlangEntry(standard: 'lama', kelantan: 'lame', phonetic: 'lame'),
  SlangEntry(standard: 'besar', kelantan: 'besar', phonetic: 'besa'),
  SlangEntry(standard: 'kecil', kelantan: 'kicik', phonetic: 'kicik'),
  SlangEntry(standard: 'cepat', kelantan: 'cepak', phonetic: 'cepak'),
  SlangEntry(standard: 'lambat', kelantan: 'lembek', phonetic: 'lembek'),
  SlangEntry(standard: 'tahu', kelantan: 'tau', phonetic: 'tau'),
  SlangEntry(standard: 'mahu', kelantan: 'nak', phonetic: 'nak'),
  SlangEntry(standard: 'habis', kelantan: 'abih', phonetic: 'abih'),
  SlangEntry(standard: 'berapa', kelantan: 'berape', phonetic: 'berape'),
  SlangEntry(standard: 'macam', kelantan: 'mcm', phonetic: 'm-c-m'),
  SlangEntry(standard: 'punya', kelantan: 'pnye', phonetic: 'p-nye'),
  SlangEntry(standard: 'banyak', kelantan: 'banyok', phonetic: 'banyok'),
  SlangEntry(standard: 'sikit', kelantan: 'siket', phonetic: 'siket'),
  SlangEntry(standard: 'sudah', kelantan: 'dah', phonetic: 'dah'),
  SlangEntry(standard: 'belum', kelantan: 'blom', phonetic: 'blom'),
  SlangEntry(standard: 'bila', kelantan: 'bile', phonetic: 'bile'),
  SlangEntry(standard: 'mana', kelantan: 'mane', phonetic: 'mane'),
  SlangEntry(standard: 'siapa', kelantan: 'sipe', phonetic: 'sipe'),
  SlangEntry(standard: 'apa', kelantan: 'ape', phonetic: 'ape'),
  SlangEntry(standard: 'kena', kelantan: 'kene', phonetic: 'kene'),
  SlangEntry(standard: 'pasang', kelantan: 'pasang', phonetic: 'pasang'),
  SlangEntry(standard: 'tukar', kelantan: 'tuka', phonetic: 'tuka'),
  SlangEntry(standard: 'baik', kelantan: 'be-ok', phonetic: 'be-ok'),
];
