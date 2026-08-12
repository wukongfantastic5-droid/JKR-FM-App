class PronunciationCorrection {
  String wrong;
  String correct;

  PronunciationCorrection({this.wrong = '', this.correct = ''});

  Map<String, dynamic> toJson() => {
    'wrong': wrong,
    'correct': correct,
  };

  factory PronunciationCorrection.fromJson(Map<String, dynamic> json) =>
    PronunciationCorrection(
      wrong: json['wrong'] as String? ?? '',
      correct: json['correct'] as String? ?? '',
    );
}

List<PronunciationCorrection> defaultPronunciationCorrections() => [
  // HVAC / ACMV
  PronunciationCorrection(wrong: 'chila', correct: 'chiller'),
  PronunciationCorrection(wrong: 'china', correct: 'chiller'),
  PronunciationCorrection(wrong: 'chilla', correct: 'chiller'),
  PronunciationCorrection(wrong: 'chilor', correct: 'chiller'),
  PronunciationCorrection(wrong: 'cheeler', correct: 'chiller'),
  PronunciationCorrection(wrong: 'siler', correct: 'chiller'),
  PronunciationCorrection(wrong: 'cela', correct: 'chiller'),
  PronunciationCorrection(wrong: 'kila', correct: 'chiller'),

  PronunciationCorrection(wrong: 'cooling tower', correct: 'cooling tower'),
  PronunciationCorrection(wrong: 'cooling towel', correct: 'cooling tower'),
  PronunciationCorrection(wrong: 'cooling towar', correct: 'cooling tower'),
  PronunciationCorrection(wrong: 'kulin tower', correct: 'cooling tower'),
  PronunciationCorrection(wrong: 'cooling tow', correct: 'cooling tower'),

  PronunciationCorrection(wrong: 'ahu', correct: 'AHU'),
  PronunciationCorrection(wrong: 'a h u', correct: 'AHU'),
  PronunciationCorrection(wrong: 'fcu', correct: 'FCU'),
  PronunciationCorrection(wrong: 'f c u', correct: 'FCU'),
  PronunciationCorrection(wrong: 'vrf', correct: 'VRF'),
  PronunciationCorrection(wrong: 'v r f', correct: 'VRF'),
  PronunciationCorrection(wrong: 'vrv', correct: 'VRV'),
  PronunciationCorrection(wrong: 'v r v', correct: 'VRV'),
  PronunciationCorrection(wrong: 'acmv', correct: 'ACMV'),
  PronunciationCorrection(wrong: 'a c m v', correct: 'ACMV'),

  PronunciationCorrection(wrong: 'compressor', correct: 'compressor'),
  PronunciationCorrection(wrong: 'compressa', correct: 'compressor'),
  PronunciationCorrection(wrong: 'kompresor', correct: 'compressor'),

  PronunciationCorrection(wrong: 'condenser', correct: 'condenser'),
  PronunciationCorrection(wrong: 'condensa', correct: 'condenser'),
  PronunciationCorrection(wrong: 'kondenser', correct: 'condenser'),

  PronunciationCorrection(wrong: 'evaporator', correct: 'evaporator'),
  PronunciationCorrection(wrong: 'evapolata', correct: 'evaporator'),
  PronunciationCorrection(wrong: 'evaporato', correct: 'evaporator'),

  PronunciationCorrection(wrong: 'damper', correct: 'damper'),
  PronunciationCorrection(wrong: 'dampa', correct: 'damper'),
  PronunciationCorrection(wrong: 'thermostat', correct: 'thermostat'),
  PronunciationCorrection(wrong: 'termo stat', correct: 'thermostat'),
  PronunciationCorrection(wrong: 'termos', correct: 'thermostat'),

  PronunciationCorrection(wrong: 'actuator', correct: 'actuator'),
  PronunciationCorrection(wrong: 'aktuator', correct: 'actuator'),
  PronunciationCorrection(wrong: 'aktuato', correct: 'actuator'),

  // Fire fighting
  PronunciationCorrection(wrong: 'sprinkler', correct: 'sprinkler'),
  PronunciationCorrection(wrong: 'sprinkla', correct: 'sprinkler'),
  PronunciationCorrection(wrong: 'springkler', correct: 'sprinkler'),
  PronunciationCorrection(wrong: 'fire pump', correct: 'fire pump'),
  PronunciationCorrection(wrong: 'firepump', correct: 'fire pump'),
  PronunciationCorrection(wrong: 'fire alarm', correct: 'fire alarm'),

  // Lift
  PronunciationCorrection(wrong: 'left', correct: 'lift'),
  PronunciationCorrection(wrong: 'gondola', correct: 'gondola'),
  PronunciationCorrection(wrong: 'gondola', correct: 'gondola'),

  // Mechanical parts
  PronunciationCorrection(wrong: 'bearing', correct: 'bearing'),
  PronunciationCorrection(wrong: 'bering', correct: 'bearing'),
  PronunciationCorrection(wrong: 'belt', correct: 'belt'),
  PronunciationCorrection(wrong: 'beld', correct: 'belt'),
  PronunciationCorrection(wrong: 'filter', correct: 'filter'),
  PronunciationCorrection(wrong: 'filtar', correct: 'filter'),
  PronunciationCorrection(wrong: 'filtra', correct: 'filter'),
  PronunciationCorrection(wrong: 'valve', correct: 'valve'),
  PronunciationCorrection(wrong: 'valv', correct: 'valve'),
  PronunciationCorrection(wrong: 'nozzle', correct: 'nozzle'),
  PronunciationCorrection(wrong: 'nozol', correct: 'nozzle'),
  PronunciationCorrection(wrong: 'impeller', correct: 'impeller'),
  PronunciationCorrection(wrong: 'impela', correct: 'impeller'),

  // Electrical
  PronunciationCorrection(wrong: 'breaker', correct: 'breaker'),
  PronunciationCorrection(wrong: 'breka', correct: 'breaker'),
  PronunciationCorrection(wrong: 'contactor', correct: 'contactor'),
  PronunciationCorrection(wrong: 'kontakta', correct: 'contactor'),
  PronunciationCorrection(wrong: 'relay', correct: 'relay'),
  PronunciationCorrection(wrong: 'rile', correct: 'relay'),

  // Plumbing
  PronunciationCorrection(wrong: 'plumbing', correct: 'plumbing'),
  PronunciationCorrection(wrong: 'plomba', correct: 'plumbing'),
  PronunciationCorrection(wrong: 'paip', correct: 'pipe'),
  PronunciationCorrection(wrong: 'piping', correct: 'piping'),

  // General
  PronunciationCorrection(wrong: 'refrigerant', correct: 'refrigerant'),
  PronunciationCorrection(wrong: 'refrijeran', correct: 'refrigerant'),
  PronunciationCorrection(wrong: 'insulation', correct: 'insulation'),
  PronunciationCorrection(wrong: 'insulasi', correct: 'insulation'),
  PronunciationCorrection(wrong: 'maintenance', correct: 'maintenance'),
  PronunciationCorrection(wrong: 'maintenan', correct: 'maintenance'),
  PronunciationCorrection(wrong: 'ppm', correct: 'PPM'),
  PronunciationCorrection(wrong: 'p m', correct: 'PM'),
  PronunciationCorrection(wrong: 'c m', correct: 'CM'),
  PronunciationCorrection(wrong: 'bms', correct: 'BMS'),
  PronunciationCorrection(wrong: 'b m s', correct: 'BMS'),
  PronunciationCorrection(wrong: 'scada', correct: 'SCADA'),
  PronunciationCorrection(wrong: 's k a d a', correct: 'SCADA'),
];

String applyPronunciationCorrections(String text, List<PronunciationCorrection> corrections) {
  if (corrections.isEmpty) return text;
  String result = text;
  for (final c in corrections) {
    if (c.wrong.isEmpty) continue;
    result = result.replaceAll(
      RegExp(c.wrong, caseSensitive: false),
      c.correct,
    );
  }
  return result;
}
