if (!Object.groupBy){
    Object.groupBy = (li, f) => {
	let out = {}
	li.forEach( itm => {
	    let key = f(itm);
	    if (!out[key]) out[key] = [];
	    out[key].push(itm);
	})
	return out;
    }
}

let abrevs = {
    "Gen":"Genèse", "Gn":"Genèse", "Ex":"Exode", "Lev":"Lévitique","Lv":"Lévitique", "Nb":"Nombres","Nom":"Nombres",
    "Dt":"Deutéronome", "Deut":"Deutéronome", "Js":"Josué", "Jos":"Josué", "Jg":"Juges", "Jug":"Juges", "Rt":"Ruth", "Ru":"Ruth",
    "1S":"1 Samuel", "2S":"2 Samuel", "1R":"1 Rois", "2R":"2 Rois", "1Ch":"1 Chroniques", "2Ch":"2 Chroniques",
    "1 S":"1 Samuel", "2 S":"2 Samuel", "1 R":"1 Rois", "2 R":"2 Rois", "1 Ch":"1 Chroniques", "2 Ch":"2 Chroniques",
    "Esd":"Esdras", "Ne":"Néhémie", "Est":"Esther",
    "Jb":"Job","Job":"Job", "Ps":"Psaumes", "Pr":"Proverbes",
    "Ec":"Ecclésiaste", "Qo":"Ecclésiaste", "Ecc":"Ecclésiaste", "Cant":"Cantique des cantiques","Ct":"Cantique des cantiques", "Es":"Ésaïe", "Is":"Ésaïe",
    "Jr":"Jérémie",
    "Lt-Jr":"Lettres de Jérémie", "La":"Lamentations","Lam":"Lamentations","Lm":"Lamentations", "Ez":"Ezéchiel",
    "Dn":"Daniel","Da":"Daniel", "Os":"Osée",
    "Jl":"Joël", "Joe":"Joël", "Am":"Amos",
    "Abd":"Abdias","Ab":"Abdias", "Jon":"Jonas", "Mi":"Michée", "Na":"Nahum", "Nah":"Nahum","Ha":"Habakuk", "Hab":"Habakuk", "So":"Sophonie",
    "Ag":"Aggée", "Agg":"Aggée", "Za":"Zacharie", "Ma":"Malachie", "Ml":"Malachie",
    "1M":"1 Macchabées", "2M":"2 Macchabées",
    "1 M":"1 Macchabées", "2 M":"2 Macchabées",
    "Ba":"Baruch", "Bar":"Baruch", "Tb":"Tobie", "Tob":"Tobie", "Jdt":"Judith", "Sa":"Sagesse", "Sg":"Sagesse", "Sa":"Sagesse",
    "Si":"Ecclésiastique", "Mt":"Matthieu","Mat":"Matthieu","Matt":"Matthieu",
    "Mc":"Marc","Mar":"Marc", "Lc":"Luc", "Jn":"Jean", "Ac":"Actes", "Act":"Actes",
    "Rm":"Romains", "Rom":"Romains", "Ro":"Romains",
    "1Co":"1 Corinthiens", "2Co":"2 Corinthiens",
    "1 Co":"1 Corinthiens", "2 Co":"2 Corinthiens",
    "1Cor":"1 Corinthiens", "2Cor":"2 Corinthiens",
    "1 Cor":"1 Corinthiens", "2 Cor":"2 Corinthiens",
    "Gal":"Galates","Ga":"Galates",
    "Eph":"Éphésiens","Ep":"Éphésiens", "Ph":"Phillippiens","Phil":"Phillippiens", "Co":"Colossiens", "Col":"Colossiens",
    "1Thess":"1 Thessaloniciens", "2Thess":"2 Thessaloniciens",
    "1 Thess":"1 Thessaloniciens", "2 Thess":"2 Thessaloniciens",

    "1Th":"1 Thessaloniciens", "2Th":"2 Thessaloniciens",
    "1 Th":"1 Thessaloniciens", "2 Th":"2 Thessaloniciens",
		      
    "1Ti":"1 Timothée", "2Ti":"2 Timothée", "1Tm":"1 Timothée", "2Tm":"2 Timothée",
    "1 Ti":"1 Timothée", "2 Ti":"2 Timothée", "1 Tm":"1 Timothée", "2 Tm":"2 Timothée",
    "Tt":"Tite", "Tit":"Tite", "Phm":"Philémon", "Hé":"Hébreux", "He":"Hébreux",
    "Jc":"Jacques","Jac":"Jacques",
    "1Pi":"1 Pierre", "2Pi":"2 Pierre",
    "1 Pi":"1 Pierre", "2 Pi":"2 Pierre",
    
    "1P":"1 Pierre", "2P":"2 Pierre",
    "1 P":"1 Pierre", "2 P":"2 Pierre",
    "1Pi":"1 Pierre", "2Pi":"2 Pierre",
    "1 Pi":"1 Pierre", "2 Pi":"2 Pierre",
    
    "1Jn":"1 Jean", "2Jn":"2 Jean", "3Jn":"3 Jean",
    "1 Jn":"1 Jean", "2 Jn":"2 Jean", "3 Jn":"3 Jean",
    "Jd":"Jude", "Jud":"Jude", "Jude":"Jude", "Ap":"Apocalypse"}

let abrevsInverse = Object.fromEntries(Object.entries(abrevs).map( ([a,b]) => [b.toLowerCase(), a]))
abrevsInverse["lamentations de jérémie"] = "La";
abrevsInverse["ézéchiel"] = "Ez";
abrevsInverse["habacuc"] = abrevsInverse["habakuk"];
abrevsInverse["actes des apôtres"] = abrevsInverse["actes"];
abrevsInverse["philippiens"] = abrevsInverse["phillippiens"];

abrevsInverse["livre de la genèse"] = abrevsInverse[abrevs["Gn"].toLowerCase()];
abrevsInverse["livre de l'exode"] = abrevsInverse[abrevs["Ex"].toLowerCase()];
abrevsInverse["livre du lévitique"] = abrevsInverse[abrevs["Lv"].toLowerCase()];
abrevsInverse["livre des nombres"] = abrevsInverse[abrevs["Nb"].toLowerCase()];
abrevsInverse["livre du deutéronome"] = abrevsInverse[abrevs["Dt"].toLowerCase()];
abrevsInverse["livre de josué"] = abrevsInverse[abrevs["Jos"].toLowerCase()];
abrevsInverse["livre des juges"] = abrevsInverse[abrevs["Jg"].toLowerCase()];
abrevsInverse["livre de ruth"] = abrevsInverse[abrevs["Rt"].toLowerCase()];
abrevsInverse["premier livre de samuel"] = abrevsInverse[abrevs["1S"].toLowerCase()];
abrevsInverse["deuxième livre de samuel"] = abrevsInverse[abrevs["2S"].toLowerCase()];
abrevsInverse["premier livre des rois"] = abrevsInverse[abrevs["1R"].toLowerCase()];
abrevsInverse["deuxième livre des rois"] = abrevsInverse[abrevs["2R"].toLowerCase()];
abrevsInverse["premier livre des chroniques"] = abrevsInverse[abrevs["1Ch"].toLowerCase()];
abrevsInverse["deuxième livre des chroniques"] = abrevsInverse[abrevs["2Ch"].toLowerCase()];
abrevsInverse["livre d'esdras"] = abrevsInverse[abrevs["Esd"].toLowerCase()];
abrevsInverse["livre de néhémie"] = abrevsInverse[abrevs["Ne"].toLowerCase()];
abrevsInverse["livre de tobie"] = abrevsInverse[abrevs["Tb"].toLowerCase()];
abrevsInverse["livre de judith"] = abrevsInverse[abrevs["Jdt"].toLowerCase()];
abrevsInverse["livre d'esther"] = abrevsInverse[abrevs["Est"].toLowerCase()];
abrevsInverse["premier livre des martyrs d'israël"] = abrevsInverse[abrevs["1M"].toLowerCase()];
abrevsInverse["deuxième livre des martyrs d'israël"] = abrevsInverse[abrevs["2M"].toLowerCase()];
abrevsInverse["livre de job"] = abrevsInverse[abrevs["Jb"].toLowerCase()];
abrevsInverse["livre des proverbes"] = abrevsInverse[abrevs["Pr"].toLowerCase()];
abrevsInverse["l'ecclésiaste"] = abrevsInverse[abrevs["Qo"].toLowerCase()];
abrevsInverse["cantique des cantiques"] = abrevsInverse[abrevs["Ct"].toLowerCase()];
abrevsInverse["livre de la sagesse"] = abrevsInverse[abrevs["Sg"].toLowerCase()];
abrevsInverse["livre de ben sira le sage"] = abrevsInverse[abrevs["Si"].toLowerCase()];
abrevsInverse["livre d'isaïe"] = abrevsInverse[abrevs["Is"].toLowerCase()];
abrevsInverse["livre de jérémie"] = abrevsInverse[abrevs["Jr"].toLowerCase()];

abrevsInverse["livre des lamentations de jérémie"] = abrevsInverse[abrevs["Lm"].toLowerCase()];

abrevsInverse["livre de baruch"] = abrevsInverse[abrevs["Ba"].toLowerCase()];
abrevsInverse["lettre de jérémie"] = abrevsInverse[abrevs["Lt-Jr"].toLowerCase()];
abrevsInverse["livre d'ezekiel"] = abrevsInverse[abrevs["Ez"].toLowerCase()];
abrevsInverse["livre de daniel"] = abrevsInverse[abrevs["Dn"].toLowerCase()];
abrevsInverse["livre d'osée"] = abrevsInverse[abrevs["Os"].toLowerCase()];
abrevsInverse["livre de joël"] = abrevsInverse[abrevs["Jl"].toLowerCase()];
abrevsInverse["livre d'amos"] = abrevsInverse[abrevs["Am"].toLowerCase()];
abrevsInverse["livre d'abdias"] = abrevsInverse[abrevs["Ab"].toLowerCase()];
abrevsInverse["livre de jonas"] = abrevsInverse[abrevs["Jon"].toLowerCase()];
abrevsInverse["livre de michée"] = abrevsInverse[abrevs["Mi"].toLowerCase()];
abrevsInverse["livre de nahum"] = abrevsInverse[abrevs["Na"].toLowerCase()];
abrevsInverse["livre d'habaquc"] = abrevsInverse[abrevs["Ha"].toLowerCase()];
abrevsInverse["livre de sophonie"] = abrevsInverse[abrevs["So"].toLowerCase()];
abrevsInverse["livre d'aggée"] = abrevsInverse[abrevs["Ag"].toLowerCase()];
abrevsInverse["livre de zacharie"] = abrevsInverse[abrevs["Za"].toLowerCase()];
abrevsInverse["livre de malachie"] = abrevsInverse[abrevs["Ml"].toLowerCase()];
abrevsInverse["evangile de jésus-christ selon saint matthieu"] = abrevsInverse[abrevs["Mt"].toLowerCase()];
abrevsInverse["evangile de jésus-christ selon saint marc"] = abrevsInverse[abrevs["Mc"].toLowerCase()];
abrevsInverse["evangile de jésus-christ selon saint luc"] = abrevsInverse[abrevs["Lc"].toLowerCase()];
abrevsInverse["evangile de jésus-christ selon saint jean"] = abrevsInverse[abrevs["Jn"].toLowerCase()];
abrevsInverse["livre des actes des apôtres"] = abrevsInverse[abrevs["Ac"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre aux romains"] = abrevsInverse[abrevs["Rm"].toLowerCase()];
abrevsInverse["première lettre de saint paul apôtre aux corinthiens"] = abrevsInverse[abrevs["1Co"].toLowerCase()];
abrevsInverse["deuxième lettre de saint paul apôtre aux corinthiens"] = abrevsInverse[abrevs["2Co"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre aux galates"] = abrevsInverse[abrevs["Ga"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre aux ephésiens"] = abrevsInverse[abrevs["Ep"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre aux philippiens"] = abrevsInverse[abrevs["Ph"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre aux colossiens"] = abrevsInverse[abrevs["Col"].toLowerCase()];
abrevsInverse["première lettre de saint paul apôtre aux thessaloniciens"] = abrevsInverse[abrevs["1Th"].toLowerCase()];
abrevsInverse["deuxième lettre de saint paul apôtre aux thessaloniciens"] = abrevsInverse[abrevs["2Th"].toLowerCase()];
abrevsInverse["première lettre de saint paul apôtre à timothée"] = abrevsInverse[abrevs["1Tm"].toLowerCase()];
abrevsInverse["deuxième lettre de saint paul apôtre à timothée"] = abrevsInverse[abrevs["2Tm"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre à tite"] = abrevsInverse[abrevs["Tt"].toLowerCase()];
abrevsInverse["lettre de saint paul apôtre à philémon"] = abrevsInverse[abrevs["Phm"].toLowerCase()];
abrevsInverse["lettre aux hébreux"] = abrevsInverse[abrevs["He"].toLowerCase()];
abrevsInverse["lettre de saint jacques apôtre"] = abrevsInverse[abrevs["Jc"].toLowerCase()];
abrevsInverse["première lettre de saint pierre apôtre"] = abrevsInverse[abrevs["1P"].toLowerCase()];
abrevsInverse["deuxième lettre de saint pierre apôtre"] = abrevsInverse[abrevs["2P"].toLowerCase()];
abrevsInverse["première lettre de saint jean"] = abrevsInverse[abrevs["1Jn"].toLowerCase()];
abrevsInverse["deuxième lettre de saint jean"] = abrevsInverse[abrevs["2Jn"].toLowerCase()];
abrevsInverse["troisième lettre de saint jean"] = abrevsInverse[abrevs["3Jn"].toLowerCase()];
abrevsInverse["lettre de saint jude"] = abrevsInverse[abrevs["Jude"].toLowerCase()];
abrevsInverse["livre de l'apocalypse"] = abrevsInverse[abrevs["Ap"].toLowerCase()];
abrevsInverse["psaumes"] = abrevsInverse[abrevs["Ps"].toLowerCase()];

let bibleLivres = Object.keys(abrevsInverse).concat(Object.keys(abrevs)).join("|")

let romains = {
    "I":1,
    "V":5,
    "X":10,
    "L":50,
    "C":100,
    "D":500,
    "M":1000
}
let romainreg = "["+Object.keys(romains).join("")+"]+"
let romainOuPasreg = "["+Object.keys(romains).join("")+"0-9]{1,3}"
// TODO gérer les chiffres romains

let rm2num = rm => {
    let number = 0;
    let acc = 0;
    let sym = 1000000;
    for (let j = 0; j < rm.length; j++){
	let v = romains[rm[j]]
	if (v > sym){
	    number += v - acc
	    acc = 0;
	}else if (v == sym){
	    acc += v
	}else{
	    number += acc;
	    acc = v;
	}
	sym = v
    }
    return number + acc;
}

let handleRomains = (reg, str) => {
    reg = new RegExp(reg, "i");
    let m = str.match(reg);
    for (let i = 1; i < m.length; i ++){
	if (m[i].match(new RegExp("^"+romainreg+"$", "g"))){
	    str = str.replace(m[i], rm2num(m[i]));
	}
    }
    return str
}
/*
console.log([ "MMMMDCCCLXXXVIII", "MDXV", "MMII", "DCLXVI", "DIX",  "XV", "XIV", "XIII", "XII", "XI", "IX"].map( rm2num ).join(" "))
console.log([4888, 1515, 2002, 666, 509, 15, 14, 13, 12, 11, 9].join(" "))
*/

export {
    handleRomains, rm2num, romainOuPasreg, romainreg, bibleLivres, abrevsInverse, abrevs
};
