
VOTING_DICTIONARY = YAML::load <<YAML_TEXT
1:
  1: Число избирателей, внесенных в список избирателей
  2: Число избирательных бюллетеней, полученных участковой избирательной комиссией
  3: Число избирательных бюллетеней, выданных избирателям, проголосовавшим досрочно
  4: Число избирательных бюллетеней, выданных избирателям в помещении для голосования
  5: Число избирательных бюллетеней, выданных избирателям вне помещения для голосования
  6: Число погашенных избирательных бюллетеней
  7: Число избирательных бюллетеней в переносных ящиках для голосования
  8: Число избирательных бюллетеней в стационарных ящиках для голосования
  9: Число недействительных избирательных бюллетеней
  10: Число действительных избирательных бюллетеней
  11: Число открепительных удостоверений, полученных участковой избирательной комиссией
  12: Число открепительных удостоверений, выданных избирателям на избирательном участке
  13: Число избирателей, проголосовавших по открепительным удостоверениям на избирательном участке
  14: Число погашенных неиспользованных открепительных удостоверений
  15: Число открепительных удостоверений, выданных избирателям территориальной избирательной комиссией
  16: Число утраченных открепительных удостоверений
  17: Число утраченных избирательных бюллетеней
  18: Число избирательных бюллетеней, не учтенных при получении
  19: Политическая партия СПРАВЕДЛИВАЯ РОССИЯ
  20: Политическая партия Либерально-демократическая партия России
  21: Политическая партия ПАТРИОТЫ РОССИИ
  22: Политическая партия Коммунистическая партия Российской Федерации
  23: Политическая партия Российская объединенная демократическая партия ЯБЛОКО
  24: Всероссийская политическая партия ЕДИНАЯ РОССИЯ
  25: Всероссийская политическая партия ПРАВОЕ ДЕЛО
  26: Число зафиксированных заявлениями нарушений
YAML_TEXT

VOTING_DICTIONARY_SHORT = YAML::load <<YAML_TEXT2
1:
  1: изб
  2: пол
  3: дос
  4: выд
  5: вне
  6: пгш
  7: ящк
  8: стц
  9: ндтв
  10: дтв
  11: опл
  12: овд
  13: опр
  14: пго
  15: овт
  16: уту
  17: утб
  18: бне
  19: СР
  20: ЛДПР
  21: ПР
  22: КПРФ
  23: ЯБЛ
  24: ЕР
  25: ПД
  26: ЧН
YAML_TEXT2
