let abbreviations =
  [
    ("Gen", "Genèse"); ("Gn", "Genèse"); ("Ex", "Exode"); ("Lev", "Lévitique"); ("Lv", "Lévitique");
    ("Nb", "Nombres"); ("Nom", "Nombres"); ("Dt", "Deutéronome"); ("Deut", "Deutéronome");
    ("Js", "Josué"); ("Jos", "Josué"); ("Jg", "Juges"); ("Jug", "Juges"); ("Rt", "Ruth"); ("Ru", "Ruth");
    ("1S", "1 Samuel"); ("2S", "2 Samuel"); ("1R", "1 Rois"); ("2R", "2 Rois");
    ("1Ch", "1 Chroniques"); ("2Ch", "2 Chroniques"); ("1 S", "1 Samuel"); ("2 S", "2 Samuel");
    ("1 R", "1 Rois"); ("2 R", "2 Rois"); ("1 Ch", "1 Chroniques"); ("2 Ch", "2 Chroniques");
    ("Esd", "Esdras"); ("Ne", "Néhémie"); ("Est", "Esther"); ("Jb", "Job"); ("Job", "Job");
    ("Ps", "Psaumes"); ("Pr", "Proverbes"); ("Ec", "Ecclésiaste"); ("Qo", "Ecclésiaste");
    ("Ecc", "Ecclésiaste"); ("Cant", "Cantique des cantiques"); ("Ct", "Cantique des cantiques");
    ("Es", "Ésaïe"); ("Is", "Ésaïe"); ("Jr", "Jérémie"); ("Lt-Jr", "Lettres de Jérémie");
    ("La", "Lamentations"); ("Lam", "Lamentations"); ("Lm", "Lamentations"); ("Ez", "Ezéchiel");
    ("Dn", "Daniel"); ("Da", "Daniel"); ("Os", "Osée"); ("Jl", "Joël"); ("Joe", "Joël");
    ("Am", "Amos"); ("Abd", "Abdias"); ("Ab", "Abdias"); ("Jon", "Jonas"); ("Mi", "Michée");
    ("Na", "Nahum"); ("Nah", "Nahum"); ("Ha", "Habakuk"); ("Hab", "Habakuk"); ("So", "Sophonie");
    ("Ag", "Aggée"); ("Agg", "Aggée"); ("Za", "Zacharie"); ("Ma", "Malachie"); ("Ml", "Malachie");
    ("1M", "1 Macchabées"); ("2M", "2 Macchabées"); ("1 M", "1 Macchabées"); ("2 M", "2 Macchabées");
    ("Ba", "Baruch"); ("Bar", "Baruch"); ("Tb", "Tobie"); ("Tob", "Tobie"); ("Jdt", "Judith");
    ("Sa", "Sagesse"); ("Sg", "Sagesse"); ("Si", "Ecclésiastique"); ("Mt", "Matthieu");
    ("Mat", "Matthieu"); ("Matt", "Matthieu"); ("Mc", "Marc"); ("Mar", "Marc"); ("Lc", "Luc");
    ("Jn", "Jean"); ("Ac", "Actes"); ("Act", "Actes"); ("Rm", "Romains"); ("Rom", "Romains");
    ("Ro", "Romains"); ("1Co", "1 Corinthiens"); ("2Co", "2 Corinthiens"); ("1 Co", "1 Corinthiens");
    ("2 Co", "2 Corinthiens"); ("1Cor", "1 Corinthiens"); ("2Cor", "2 Corinthiens");
    ("1 Cor", "1 Corinthiens"); ("2 Cor", "2 Corinthiens"); ("Gal", "Galates"); ("Ga", "Galates");
    ("Eph", "Éphésiens"); ("Ep", "Éphésiens"); ("Ph", "Phillippiens"); ("Phil", "Phillippiens");
    ("Co", "Colossiens"); ("Col", "Colossiens"); ("1Thess", "1 Thessaloniciens");
    ("2Thess", "2 Thessaloniciens"); ("1 Thess", "1 Thessaloniciens");
    ("2 Thess", "2 Thessaloniciens"); ("1Th", "1 Thessaloniciens"); ("2Th", "2 Thessaloniciens");
    ("1 Th", "1 Thessaloniciens"); ("2 Th", "2 Thessaloniciens"); ("1Ti", "1 Timothée");
    ("2Ti", "2 Timothée"); ("1Tm", "1 Timothée"); ("2Tm", "2 Timothée"); ("1 Ti", "1 Timothée");
    ("2 Ti", "2 Timothée"); ("1 Tm", "1 Timothée"); ("2 Tm", "2 Timothée"); ("Tt", "Tite");
    ("Tit", "Tite"); ("Phm", "Philémon"); ("Hé", "Hébreux"); ("He", "Hébreux"); ("Jc", "Jacques");
    ("Jac", "Jacques"); ("1Pi", "1 Pierre"); ("2Pi", "2 Pierre"); ("1 Pi", "1 Pierre");
    ("2 Pi", "2 Pierre"); ("1P", "1 Pierre"); ("2P", "2 Pierre"); ("1 P", "1 Pierre");
    ("2 P", "2 Pierre"); ("1Jn", "1 Jean"); ("2Jn", "2 Jean"); ("3Jn", "3 Jean");
    ("1 Jn", "1 Jean"); ("2 Jn", "2 Jean"); ("3 Jn", "3 Jean"); ("Jd", "Jude");
    ("Jud", "Jude"); ("Jude", "Jude"); ("Ap", "Apocalypse");
  ]

let inverse_aliases =
  [
    ("lamentations de jérémie", "La");
    ("ézéchiel", "Ez");
    ("habacuc", "Ha");
    ("actes des apôtres", "Ac");
    ("philippiens", "Ph");
    ("livre de la genèse", "Gn");
    ("livre de l'exode", "Ex");
    ("livre du lévitique", "Lv");
    ("livre des nombres", "Nb");
    ("livre du deutéronome", "Dt");
    ("livre de josué", "Jos");
    ("livre des juges", "Jg");
    ("livre de ruth", "Rt");
    ("premier livre de samuel", "1S");
    ("deuxième livre de samuel", "2S");
    ("premier livre des rois", "1R");
    ("deuxième livre des rois", "2R");
    ("premier livre des chroniques", "1Ch");
    ("deuxième livre des chroniques", "2Ch");
    ("livre d'esdras", "Esd");
    ("livre de néhémie", "Ne");
    ("livre de tobie", "Tb");
    ("livre de judith", "Jdt");
    ("livre d'esther", "Est");
    ("premier livre des martyrs d'israël", "1M");
    ("deuxième livre des martyrs d'israël", "2M");
    ("livre de job", "Jb");
    ("livre des proverbes", "Pr");
    ("l'ecclésiaste", "Qo");
    ("cantique des cantiques", "Ct");
    ("livre de la sagesse", "Sg");
    ("livre de ben sira le sage", "Si");
    ("livre d'isaïe", "Is");
    ("livre de jérémie", "Jr");
    ("livre des lamentations de jérémie", "Lm");
    ("livre de baruch", "Ba");
    ("lettre de jérémie", "Lt-Jr");
    ("livre d'ezekiel", "Ez");
    ("livre de daniel", "Dn");
    ("livre d'osée", "Os");
    ("livre de joël", "Jl");
    ("livre d'amos", "Am");
    ("livre d'abdias", "Ab");
    ("livre de jonas", "Jon");
    ("livre de michée", "Mi");
    ("livre de nahum", "Na");
    ("livre d'habaquc", "Ha");
    ("livre de sophonie", "So");
    ("livre d'aggée", "Ag");
    ("livre de zacharie", "Za");
    ("livre de malachie", "Ml");
    ("evangile de jésus-christ selon saint matthieu", "Mt");
    ("evangile de jésus-christ selon saint marc", "Mc");
    ("evangile de jésus-christ selon saint luc", "Lc");
    ("evangile de jésus-christ selon saint jean", "Jn");
    ("livre des actes des apôtres", "Ac");
    ("lettre de saint paul apôtre aux romains", "Rm");
    ("première lettre de saint paul apôtre aux corinthiens", "1Co");
    ("deuxième lettre de saint paul apôtre aux corinthiens", "2Co");
    ("lettre de saint paul apôtre aux galates", "Ga");
    ("lettre de saint paul apôtre aux ephésiens", "Ep");
    ("lettre de saint paul apôtre aux philippiens", "Ph");
    ("lettre de saint paul apôtre aux colossiens", "Col");
    ("première lettre de saint paul apôtre aux thessaloniciens", "1Th");
    ("deuxième lettre de saint paul apôtre aux thessaloniciens", "2Th");
    ("première lettre de saint paul apôtre à timothée", "1Tm");
    ("deuxième lettre de saint paul apôtre à timothée", "2Tm");
    ("lettre de saint paul apôtre à tite", "Tt");
    ("lettre de saint paul apôtre à philémon", "Phm");
    ("lettre aux hébreux", "He");
    ("lettre de saint jacques apôtre", "Jc");
    ("première lettre de saint pierre apôtre", "1P");
    ("deuxième lettre de saint pierre apôtre", "2P");
    ("première lettre de saint jean", "1Jn");
    ("deuxième lettre de saint jean", "2Jn");
    ("troisième lettre de saint jean", "3Jn");
    ("lettre de saint jude", "Jude");
    ("livre de l'apocalypse", "Ap");
    ("psaumes", "Ps");
  ]

let bible_books_pattern =
  let entries =
    List.map fst abbreviations
    @ List.map fst inverse_aliases
    |> List.sort_uniq String.compare
  in
  String.concat "|" entries

let roman_values = [ ('I', 1); ('V', 5); ('X', 10); ('L', 50); ('C', 100); ('D', 500); ('M', 1000) ]

let roman_pattern =
  let chars = roman_values |> List.map (fun (c, _) -> String.make 1 c) |> String.concat "" in
  "[" ^ chars ^ "]+"

let roman_or_decimal_pattern =
  let chars = roman_values |> List.map (fun (c, _) -> String.make 1 c) |> String.concat "" in
  "[" ^ chars ^ "0-9]{1,3}"

let roman_value c = List.assoc (Char.uppercase_ascii c) roman_values

let rm2num roman =
  let rec loop index previous acc =
    if index >= String.length roman then acc
    else
      let value = roman_value roman.[index] in
      if value > previous then loop (index + 1) value (acc + value - (2 * previous))
      else loop (index + 1) value (acc + value)
  in
  loop 0 0 0

let is_roman text = Str.string_match (Str.regexp ("^" ^ roman_pattern ^ "$")) text 0

let handle_romans pattern text =
  let regexp = Str.regexp_case_fold pattern in
  if Str.string_match regexp text 0 then
    let rec replace_group index acc =
      if index > 9 then acc
      else
        match Str.group_beginning index with
        | exception Invalid_argument _ -> acc
        | start_pos ->
            let end_pos = Str.group_end index in
            let group = String.sub acc start_pos (end_pos - start_pos) in
            if is_roman group then
              let replacement = string_of_int (rm2num group) in
              let prefix = String.sub acc 0 start_pos in
              let suffix = String.sub acc end_pos (String.length acc - end_pos) in
              replace_group (index + 1) (prefix ^ replacement ^ suffix)
            else replace_group (index + 1) acc
      in
    replace_group 1 text
  else text
