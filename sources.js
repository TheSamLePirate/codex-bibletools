
import {handleRomains, rm2num, romainOuPasreg, romainreg, bibleLivres, abrevsInverse, abrevs} from "./bibleTools.js";

import { throwF, Cache, CacheAsync, firstWord } from "./std.js"

let ID = o => o.ID ? o.ID : 1;


let bibles = {
    "Louis Segond (1910) (Calviniste)":Cache("bible.json"),
    "bible lithurgique catholique":Cache("bible_aelf.json"),
    "Bible Parole de Vie (pour enfant, protestante évangélique)":Cache("bibleParoleDeVie.json"),
    "Bible de l'épée (Calviniste)":Cache("bibleEpee.json"),
    "Bible Martin (Protestante)":Cache("bibleMartin.json"),
    "Bible Ostervald (Protestante)":Cache("bibleOster.json"),
    "Bible du Semeur (évangélique)":Cache("bibleSemeur.json"),
    "Bible TOB (catholique et protestante)":Cache("bibleTOB.json"),
    "Bible Traduction du monde nouveau (édition révisée de 2018, témoins de jéhovah)":Cache("bible_jehovah.json")
}
let biblesRes = Object.values(bibles);
let biblesNames = Object.keys(bibles);
let bibleIndex = 0;
let changeBible = n => {
    if (n !== "") bibleIndex = n;
}

let loadDocuments = (addTextContent, makeL, langue) => {
    let allBooks = assoc => assoc.Testaments.map(x => x.Books).reduce( (a, b) => a.concat(b), []);
    let findLivre = (assoc, livre) => {
        //console.log(allBooks(assoc).map( x => "abrevsInverse[\""+ x.Text.toLowerCase() + "\"] = abrevsInverse[abrevs[\"" + x.url.replace("http://aelf.org/bible/", "").match(/(.*)\//)[1]+"\"].toLowerCase()];").join("\n"))
        return allBooks(assoc).find(x => abrevsInverse[x.Text.toLowerCase()] == abrevsInverse[
        abrevs[livre] ? abrevs[livre].toLowerCase() : ""])
    }
    let resCatX = Cache("catechisme_pieX.json")
    let resCatT = Cache("catechisme_trente.json")
    let resRael = Cache("Rael.json")
    
    let makenav = (prefix, first, last, pageF, pageT) => [
	prefix+first,
	pageF > first ? prefix + (pageF*1-1) : false,
	pageF > first ? prefix + (pageF*1-1) + "-" + (pageT ? pageT : pageF) : false,
	prefix + first + "-" + last,
	(pageT?pageT:pageF) < last ? prefix + pageF + "-" + ((pageT ? pageT : pageF)*1+1) : false,
	(pageT?pageT:pageF) < last ? prefix+ ((pageT ? pageT : pageF)*1+1) : false,
	prefix + last
    ]
    let nonav = [false, false, false, false, false, false, false]
    let coran_lang_indirection = {
	"français":"text",
	"english":"text",
	"arabic":"text_arabe"
    }

    let hadithsByDate = {
	"tirmidhi":892,
	"shamail":892,
	"muslim":875,
	"bukhari":870,
	"ibnmajah":886,
	"nasai":915,
	"ahmad":855,
	"abudawud":889,
	"riyadussalihin":0,
	"mishkat":0,
	"bulugh":0,
	"adab":0,
	
	"nawawi40":1277,
	"shahwaliullah40":0,
	"qudsi40":0,
	"hisn":0,
    }
    let hadiths = Object.keys(hadithsByDate)
    let HadithsPrefix = hadiths.join("|")

    let cmpStr = (a, b) => {
	let r = parseInt(a) - parseInt(b)
	if (r == 0) r = a < b ? -1 : a > b ? 1 : 0;
	return r;
    }
    let fixHadithsRef = (zero, li) => li.forEach( h => {
	if (! h.ref["In-book reference"]){
	    let a = h.ref.Reference.match(/^Hadith (\d+), (\d+)/);
	    if (a){
		h.ref["In-book reference"] = { Hadith: a[1], Book:a[2] }
	    }else{
		a = h.ref.Reference.match(/^Hisn al-Muslim (\d+)/);
		h.ref["In-book reference"] = { Hadith: a[1], Book:1 } // hack un peu à chier
	    }
	}else if (typeof(h.ref["In-book reference"]) == "string"){
	    let a = h.ref["In-book reference"].match(/^(Introduction), (Hadith|Narration) (\d+)/) || h.ref["In-book reference"].match(/^Book (\d+[a-z]?), Hadith (\d+)/);
	    if (a[1] != "Introduction")
		h.ref["In-book reference"] = { Book: a[1], Hadith:a[2]}
	    else h.ref["In-book reference"] = { Book: zero ? 0 : a[1], Hadith:a[2]}
	}
    })
    
    let resHadithsBooks = hadiths.map( name => [name, Cache(name+".json")])
    let resHadiths = Object.fromEntries( resHadithsBooks.map( ([name, promise]) => [name, CacheAsync(promise, li => {
	li = JSON.parse(JSON.stringify(li))
	fixHadithsRef(true, li)
	li = Object.groupBy(li, x => x.ref["In-book reference"].Book)
	for (let key in li)
	    li[key].sort( (a,b) => cmpStr(a.ref["In-book reference"].Hadith, b.ref["In-book reference"].Hadith))
	//li = Object.entries(li).sort( ([ k1, v1], [k2, v2]) => cmpStr(k1, k2)).reduce((r, [k, v]) => ({ ...r, [k]: v }), {});
	
	return li;
    })]))
			  

    let resHadithsByNumbers = Object.fromEntries( resHadithsBooks.map( ([name, promise]) => [name, CacheAsync(promise, li => {
	li = JSON.parse(JSON.stringify(li))
	fixHadithsRef(false, li)
	return Object.fromEntries( li.map( i => [i.number, i]))
    })]))

    let fillHadith = (node, verses) => {

	let links2Coran = [ makeL(/\((\d+)[:\.](\d+)\)/g, "Coran:$1.$2"),
			    makeL(/\((\d+)[:\.](\d+)-(\d+)\)/g, "Coran:$1.$2-$3"),
			    makeL(/\(Coran, (\d+)[:\.](\d+)\)/g, "Coran:$1.$2"),
			    makeL(/\(Coran, (\d+)[:\.](\d+)-(\d+)\)/g, "Coran:$1.$2-$3"),

			  ]
	
	verses.forEach( item => {

	    let firstLine = node.appendChild(document.createElement("p"))
	    if (item.grade){
		let g = firstLine.appendChild(document.createElement("span"))
		g.innerText = item.grade
		g.className="HadithGrade"
	    }
	    
	    let ref = firstLine.appendChild( document.createElement("span"))
	    ref.innerText = item.author + "."+ item.number + " Book " + (item.ref["In-book reference"].Book == 0 ? "Introduction" : item.ref["In-book reference"].Book) + " Hadith " + item.ref["In-book reference"].Hadith
	    ref.className="HadithId"
	    if (langue.value == "arabic"){
		let r = node.appendChild( document.createElement("div"))
		addTextContent(r, item.arabic, true, [], links2Coran)
	    }else{
		let q = node.appendChild( document.createElement("div"))
		q.className="Narrator"
		let r = node.appendChild( document.createElement("div"))
		if (langue.value == "français"){
		    addTextContent(q, item.french_narator, true, [], links2Coran)
		    addTextContent(r, item.french, true, [], links2Coran)
		    let n = node.appendChild( document.createElement("div"))
		    let p = addTextContent(n, "traduction automatique depuis l'anglais. ", true)
		    let spanNote = p.appendChild(document.createElement("span"))
		    spanNote.appendChild(document.createTextNode("(vérifiez en anglais car c'est souvent pas terrible)"))

		    spanNote.style["font-style"] = "italic"
		    spanNote.style["font-size"] = "smaller"
		    n.className="note"
		}else{
		    addTextContent(q, item.narator, true, [], links2Coran)
		    addTextContent(r, item.english, true, [], links2Coran)
		}
	    }
	})
    }
    
    return {
	Bible:{
	    res:() => biblesRes[bibleIndex](),
	    valid : "Chrétiennes/Bible",
	    source: (bible, [query, livre, chapitre, verset]) => {
                 let a = Object.values(findLivre(bible, livre).Chapters).find(x => ID(x) == chapitre);
                 if (a.url) return a.url;
                 else return "https://www.biblegateway.com/passage/?search="+encodeURI(abrevs[livre])+"+"+chapitre+"&version=LSG"
             },
	    input1:/^(.+)\-([0-9A-Z]+):(\d+)$/,
	    input2:/^(.+)\-([0-9A-Z]+):(\d+)\-(\d+)$/,
	    nrefs:2,
	    className:"btnBible",
	    nomenclature:["Bible", "livre", "chapitre", "verset"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses.map(v => ID(v) + " " + v.Text), true),
	    bibData: (verses, fulldoc, path) => ({note:verses.map(v => ID(v) + " " + v.Text).join("")}),
	    title: [undefined,
		    (bible, livre, livreIndex) => livre.Text,
		    (livre, chapitre, chap) => "chapitre " + chap],
	    access:[undefined, findLivre,
		    (assoc, chapitre) => Object.values(assoc.Chapters).find(x => ID(x) == chapitre)?.Verses
		   ],
	    index:[
		(bible) => allBooks(bible).map(x => x.Text),
		((bible, [livre]) => Object.values(findLivre(bible, abrevsInverse[livre ? livre.toLowerCase() : ""]).Chapters).map(ID)),
		((bible, [livre, chapitre]) => Object.values(findLivre(bible, abrevsInverse[livre.toLowerCase()]).Chapters).find(x => ID(x) == chapitre)?.Verses.map(ID))
	    ],
	    compileRef : ( [livre, chapitre, verset] ) => abrevsInverse[livre.toLowerCase()]+"-"+chapitre+":"+verset,
	    iterV: (bible, f) => allBooks(bible).forEach( b => Object.values(b.Chapters).forEach( c => c.Verses.forEach( v => {
                if (!v) {
                    console.log("Bad Verse? " + b.Text + " chapitre " + ID(c));
                }else {
                    return f(abrevsInverse[b.Text.toLowerCase()]+"-"+ID(c)+":"+ID(v), v.Text  );
                }
            }))),
	    navigation : (assoc, [_, livre, chapitre, versetF, versetT]) => makenav(livre+"-"+chapitre+":", 1, assoc.length, versetF, versetT)
	},
	Hadiths:{
	    option:"Hadiths par livre",
	    res: async () => resHadiths,
	    valid : "Islam/Hadiths",
	    input1:new RegExp("("+HadithsPrefix+")\\.(\\d+[a-z]?)\\.(\\d+)", "i"),
	    input2:new RegExp("("+HadithsPrefix+")\\.(\\d+[a-z]?)\\.(\\d+)-(\\d+)", "i"),
	    source: (Q, [_, name, book, number]) => Q[name]().then( res => "https://www.sunnah.com/"+name+":"+res[book][number - 1].number),
	    sourceName: "sunnah.com",
	    nrefs:2,
	    className:"btnHadiths",
	    index:[ obj => Object.keys(obj),
		    (obj, [name]) => obj[name]().then(x => Object.keys(x).sort(cmpStr)) ],
	    nomenclature:["hadith", "auteur", "livre", "numéro"],
	    title: ["Hadiths", (assoc, _, name) => name,
		    (assoc, _, number) => "livre "+number,
		    (assoc, _, number) => "hadith "+number],
	    access:[ undefined,
		     (obj, name) => obj[name](),
		     (obj, num) => obj[num]
		   ],
	    countArticles : (obj, [name, book]) => obj[name]().then( x => x[book].length),
	    fillWithVerses: fillHadith,
	    compileRef : ([author, book, num]) => author+"."+book+"."+num,
	    navigation : (assoc, [_, author, book, versetF, versetT]) => nonav
	},
	Hadiths2:{
	    option:"Hadiths par numéro",
	    res: async () => resHadithsByNumbers,
	    valid: "Islam/Hadiths",
	    input1:new RegExp("("+HadithsPrefix+")\\:(\\d+[a-z]?)", "i"),
	    source: (Q, [_, name, number]) => Q[name]().then( res => "https://www.sunnah.com/"+name+":"+number),
	    sourceName: "sunnah.com",
	    nrefs:1,
	    className:"btnHadiths",
	    index:[ obj => Object.keys(obj) ],
	    nomenclature:["hadith", "auteur", "numéro"],
	    title: ["Hadiths", (assoc, _, name) => name,
		    (assoc, _, number) => "hadith "+number],
	    access:[ undefined,
		     (obj, name) => obj[name]() ],
	    fillWithVerses: fillHadith,
	    bibData: (verses, fulldoc, path) => ({
		author:path[0],
		note:verses.map(v => v.french).join("")}),
	    compileRef : ([author, num]) => author+":"+num,
	    navigation : (assoc, [_, author, book, versetF, versetT]) => nonav,
	    iterV: (assoc, f) => Promise.all(Object.entries(assoc).map(([name, res]) => res().then( hadiths => Object.entries(hadiths).forEach( ([number, hadith]) => f(name+":"+number, hadith.french) ))))
	},
	Rael:{
	    res:resRael,
	    valid: "Sectes/Rael",
	    source: (Q, [_, doc]) => Q[doc].url,
	    sourceName: "pdf",
	    input1:/^Rael\.(\d+)\.(\d+)\.(\d+)$/,
	    input2:/^Rael\.(\d+)\.(\d+)\.(\d+)-(\d+)$/,
	    nrefs:2,
	    className:"btnRael",
	    nomenclature:["Rael", "Livre", "Chapitre"],
	    title:["Rael",
		   (assoc, livre) => livre.title,
		   (livre, _, chap) => livre.sections[chap].title
		  ],
	    index:[
		(docs) => docs.map(x => x.title),
		(docs, [title]) => docs.find(x => x.title == title).sections.map(x => x.title),
		(docs, [title, chapter]) => docs.find(x => x.title == title).sections.find(x => x.title == chapter).pages.map( x => x.page)
	    ],
	    offset: (docs, [_, livre, chapter]) => docs[livre].sections[chapter].page,
	    access:[undefined,
		    (assoc, livre) => assoc[livre],
		    (assoc, chap) => assoc.sections[chap].pages.map(x => x.text)
		   ],
	    compileRef: ([livre, section, indice]) => resRael().then(
		docs => "Rael."+ docs.findIndex(x => x.title == livre)+ "."+ docs.find(x => x.title == livre).sections.findIndex(x => x.title == section)+ "."+ indice),
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    navigation: (assoc, [_, livre, chapter, pageF, pageT], offset) => makenav("Rael." + livre + "." + chapter+ ".", offset, assoc.length - 1 + offset, pageF, pageT),
	    iterV: (doc, f) => doc.forEach( (part, parti) => part.sections.forEach( (chap, chapi) => chap.pages.forEach( (page, pagei) => f("Rael."+parti+"."+chapi+"."+page.page, page.text.join(" ")))))
	},
	Coran:{
	    res:Cache("quran.json"),
	    valid : "Islam/Coran",
	    source: (Q, path) =>"https://quranx.com/tafsirs/"+path[1]+"."+path[2],
	    sourceName:"Tafsir",
	    input1:/^Coran\:(\d+)\.(\d+)$/,
	    input2:/^Coran\:(\d+)\.(\d+)-(\d+)$/,
	    nrefs:1,
	    className:"btnCoran",
	    nomenclature:["Coran", "sourate", "verset"],
	    fillWithVerses: (dad, verses) =>
		addTextContent(dad, verses.map(v => v.position_ds_sourate + " " + v[coran_lang_indirection[langue.value]]), true),
	    
	    bibData: (verses, fulldoc, path) => ({note:verses.map(v => v.position_ds_sourate + " " + v.français).join("")}),
	    title: [undefined,
		    (coran, versets, sourate) =>{
			return coran.sourates[sourate-1].nom_phonetique + " ("+coran.sourates[sourate-1].nom+" "+coran.sourates[sourate-1].nom_sourate+", "+coran.sourates[sourate-1].revelation+") " + coran.sourates[sourate-1].position
		    }
		   ],
	    access:[undefined,
		    (assoc, sourate) => assoc.sourates[sourate-1].versets
		   ],
	    index:[
		(coran) => coran.sourates.map(s => s.position + " " + s.nom_sourate),
		(coran, [sourate]) => coran.sourates[sourate.match(/^\d+/)[0]*1-1].versets.map(v => v.position_ds_sourate)
	    ],
	    compileRef: ([sourate, verset]) => "Coran:"+(sourate.match(/^\d+/)[0])+"."+verset,
	    iterV: (coran, f) => coran.sourates.forEach(s => s.versets.forEach( v => f("Coran:"+s.position+"."+v.position_ds_sourate,v.text))),
	    navigation : (assoc, [_, chapitre, versetF, versetT]) => makenav("Coran:"+chapitre+".", 1, assoc.length, versetF, versetT)
	},
	Can:{
	    res:Cache("can.json"),
	    valid : "Chrétiennes/Catholiques/Canonique",
            source: (Q, [_, index]) => "https://www.droitcanonique.fr/codes/cic-1983-1/c-"+index+"-cic-1983-"+index,
	    input1:/^Can\.(\d+)$/,
	    input2:/^Can\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCan",
	    nomenclature:["Code canonique", "article"],
	    title:["Canon"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    countArticles : document => document.length,
	    compileRef : index => "Can."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Can."+(i+1), v)),
	    navigation : (assoc, [_, versetF, versetT]) => makenav("Can.", 1, assoc.length, versetF, versetT)
	},
	DH:{
	    res:Cache("denzinger.json"),
	    valid : "Chrétiennes/Catholiques/Denzinger",
	    input1:/^DH\.(\d+)$/,
	    input2:/^DH\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnDH",
	    nomenclature:["Denzinger", "numéro"],
	    title:["Denzinger"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    countArticles : document => document.length,
	    compileRef : index => "DH."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("DH."+(i+1), v)),
	    navigation : (assoc, [_, versetF, versetT]) => makenav("DH.", 1, assoc.length, versetF, versetT)
	},
	Can1917:{
	    res:Cache("can1917.json"),
	    valid : "Chrétiennes/Catholiques/Canonique",
            source: (Q, [_, index]) => "https://www.droitcanonique.fr/codes/cic-1917-15/c-"+index+"-cic-1917-"+(1764+index*1),
	    input1:/^Can1917\.(\d+)$/,
	    input2:/^Can1917\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCan",
	    nomenclature:["Code canonique 1917", "article"],
	    title:["Code canonique 1917"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true, [],
                                                            [ makeL(/can\.\s*(\d+)/g, "Can1917.$1") ]),
	    countArticles : document => document.length,
	    compileRef : index => "Can1917."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Can1917."+(i+1), v)),
	    navigation : (assoc, [_, versetF, versetT]) => makenav("Can1917.", 1, assoc.length, versetF, versetT)
	},
	Can1990:{
	    res:Cache("can1990.json"),
	    valid : "Chrétiennes/Catholiques/Canonique",
            source: (Q, [_, index]) => "https://www.droitcanonique.fr/codes/cceo-1990-13/c-"+index+"-cceo-1990-"+(4280+index*1),
	    input1:/^Can1990\.(\d+)$/,
	    input2:/^Can1990\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCan",
	    nomenclature:["Code canonique des églises orientales de 1990", "article"],
	    title:["Code canonique des églises orientales de 1990"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true, [],
                                                            [ makeL(/can\.\s*(\d+)/g, "Can1990.$1") ]),
	    countArticles : document => document.length,
	    compileRef : index => "Can1990."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Can1990."+(i+1), v)),
	    navigation : (assoc, [_, versetF, versetT]) => makenav("Can1990.", 1, assoc.length, versetF, versetT)
	},
	Catechisme:{
	    res:Cache("catechisme.json"),
	    valid : "Chrétiennes/Catholiques/Catéchismes",
	    source:"https://www.vatican.va/archive/FRA0013/_INDEX.HTM",
	    input1:/^Cat\.(\d+)$/,
	    input2:/^Cat\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCat",
	    nomenclature:["Catéchisme", "article"],
	    title:["Catéchisme"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    countArticles : document => document.length,
	    compileRef : index => "Cat."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Cat."+(i+1), v)),
	    navigation : (assoc, [_, versetF, versetT]) => makenav("Cat.", 1, assoc.length - 1, versetF, versetT)
	},
	CatechismeE:{
	    res:Cache("catechismeEveques.json"),
	    valid : "Chrétiennes/Catholiques/Catéchismes",
	    input1:/^CatE\.(\d+)$/,
	    input2:/^CatE\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCatE",
	    nomenclature:["Catéchisme des éveques de France", "article"],
	    title:["Catéchisme des éveques de France"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    countArticles : document => document.length,
	    compileRef : index => "CatE."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("CatE."+(i+1), v)),
	    navigation: (assoc, [_, pageF, pageT], offset) => makenav("CatE.", offset, assoc.length - 1 + offset, pageF, pageT)
	},
	CatechismeTrente:{
	    res:resCatT,
	    valid : "Chrétiennes/Catholiques/Catéchismes",
	    input1:/^CatT\.(\d+)\.(\d+)\.(\d+)\.(\d+)$/,
	    input2:/^CatT\.(\d+)\.(\d+)\.(\d+)\.(\d+)-(\d+)$/,
	    nrefs:3,
	    className:"btnCatT",
	    nomenclature:["Catéchisme du concile de trente", "Partie", "Chapitre", "paragraphe", "phrase"],
	    title:["Catéchisme du concile de trente\n",
		   (doc, part) => part.title+"\n",
		   (part, chapter) => chapter.title+"\n",
		   (chapter, _, par) => chapter.paras[par].title,
		  ],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    access:[undefined,
		    (assoc, section) => assoc.parts[section],
		    (assoc, chapter) => assoc.chapters[chapter],
		    (assoc, para) => assoc.paras[para].text,
		   ],
	    index:[
		(doc) => doc.parts.map(x => x.title),
		(doc, [part]) => doc.parts.find(x => x.title == part).chapters.map(x => x.title),
		(doc, [part, chap]) => doc.parts.find(x => x.title == part).chapters.find(x => x.title == chap).paras.map(x => x.title),
		(doc, [part, chap, para]) => doc.parts.find(x => x.title == part).chapters.find(x => x.title == chap).paras.find(x => x.title == para).text.map( (_, i) => i+1),
	    ],
	    iterV: (doc, f) => doc.parts.forEach( (part, parti) => part.chapters.forEach( (chap, chapi) => chap.paras.forEach( (para, parai) => para.text.forEach(
		(text, texti) => f("CatT."+parti+"."+chapi+"."+parai+"."+(texti+1), text))))),
	    compileRef: ([section, chapter, para, indice]) => resCatT().then(
		res => "CatT."+res.parts.findIndex(x => x.title == section) + "."+
		    res.parts.find(x => x.title == section).chapters.findIndex(x => x.title == chapter) + "."+
		    res.parts.find(x => x.title == section).chapters.find(x => x.title == chapter).paras.findIndex(x => x.title == para) +
		    "."+indice),
	    navigation: (assoc, [_, section, chapter, para, pageF, pageT], offset) => makenav("CatT." + section + "." + chapter+ "."+ para + ".", offset, assoc.length - 1 + offset, pageF, pageT)
	},
	CatechismeX:{
	    res:resCatX,
	    valid : "Chrétiennes/Catholiques/Catéchismes",
	    input1:/^CatX\.(\d+)\.(\d+)\.(\d+)$/,
	    input2:/^CatX\.(\d+)\.(\d+)\.(\d+)-(\d+)$/,
	    nrefs:2,
	    className:"btnCatX",
	    nomenclature:["Catéchisme de Pie X", "Partie", "Chapitre", "Page"],
	    title:["Catéchisme de Pie X\n",
		   (_, section) => section.title+"\n",
		   (section, _, indice) => section.chapters[indice].title+"\n"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    access:[undefined,
		    (assoc, section) => assoc.sections[section],
		    (assoc, chapter) => assoc.chapters[chapter].pages.map(x => x.text),
		   ],
	    index:[
		(pdf) => pdf.sections.map(x => x.title),
		(pdf, [part]) => pdf.sections.find(x => x.title == part).chapters.map(x => x.title),
		(pdf, [part, chap]) => pdf.sections.find(x => x.title == part).chapters.find(x => x.title == chap).pages.map(x => x.page),
	    ],
	    iterV: (pdf, f) => pdf.sections.forEach( (section, sectioni) => section.chapters.forEach( (chap, chapi) => chap.pages.forEach(
		page => f("CatX."+sectioni+"."+chapi+"."+page.page, page.text.join(""))))),
	    compileRef: ([section, chapter, page]) => resCatX().then( res => "CatX."+res.sections.findIndex(x => x.title == section) + "."+res.sections.find(x => x.title == section).chapters.findIndex(x => x.title == chapter) + "."+page),
	    offset: (pdf, [_, section, chapter]) => pdf.sections[section].chapters[chapter].page,
	    navigation: (assoc, [_, section, chapter, pageF, pageT], offset) => makenav("CatX." + section + "." + chapter+ ".", offset, assoc.length - 1 + offset, pageF, pageT)
	},
	Compendium:{
	    res:Cache("compendium.json"),
	    valid : "Chrétiennes/Catholiques/Catéchismes",
	    source:"https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_fr.html",
	    input1:/^Cat\.Comp\.(\d+)$/,
	    input2:/^Cat\.Comp\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnCatComp",
	    nomenclature:["Compendium du catéchisme", "article"],
	    title:["Compendium du Catéchisme"],
	    fillWithVerses : (node, items) => {
		node.innerHTML = "";
		let link2Catechisme = [
		    makeL(/\n(\d+)\-(\d+)/g, "Cat.$1-$2"),
		    makeL(/\n(\d+)/g, "Cat.$1")]
		items.forEach( item => {
		    let q = node.appendChild( document.createElement("p"))
		    addTextContent(q, item.Q, false, [], link2Catechisme)
		    q.className="Question"
		    let r = node.appendChild( document.createElement("p"))
		    addTextContent(r, item.R, false, [], link2Catechisme)
		    r.className="Response"
		})
	    },
	    countArticles : document => document.length,
	    compileRef : index => "Cat.Comp."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Cat.Comp."+(i+1), v.Q+"\n"+v.R)),
	    navigation : (assoc, [_, versetF, versetT], offset) =>  makenav("Cat.Comp.", offset, assoc.length - 1 + offset, versetF, versetT)
	},
	CompendiumSocial:{
	    res:Cache("compendium_sociale.json"),
	    valid : "Chrétiennes/Catholiques/Social",
	    source:"https://www.vatican.va/roman_curia/pontifical_councils/justpeace/documents/rc_pc_justpeace_doc_20060526_compendio-dott-soc_fr.html#J%C3%A9sus-Christ,%20prototype%20et%20fondement%20de%20la%20nouvelle%20humanit%C3%A9",
	    title:["Compendium doctrine sociale"],
	    input1:/^Soc\.(\d+)$/,
	    input2:/^Soc\.(\d+)-(\d+)$/,
	    nrefs:0,
	    className:"btnSocial",
	    nomenclature:["Compendium de la doctrine sociale", "article"],
	    fillWithVerses: (dad, verses) => addTextContent(dad, verses, true),
	    countArticles : document => document.length,
	    compileRef : index => "Soc."+index,
	    iterV: (array, f) => array.forEach( (v, i) => v && f("Soc."+(i+1), v.join("\n"))),
	    navigation : (assoc, [_, versetF, versetT], offset) =>  makenav("Soc.", offset, assoc.length - 1 + offset, versetF, versetT)
	},
	Vatican:{
	    res: Cache("Vatican_map.json", map => Object.fromEntries(Object.entries(map).map( ([cat, file]) => [cat, Cache(file, encycliques => {
		let obj = {}
		encycliques.sort( (a, b) => a.title.localeCompare(b.title))
		encycliques.forEach( e => {
		    if (obj[e.date]){
			let suffix = 1
			while (obj[e.date+"-"+suffix]) suffix++;
			obj[e.date+"-"+suffix] = e
		    }else{
			obj[e.date] = e
		    }
		})
		return obj;
	    } ) ]))),
	    valid : "Chrétiennes/Catholiques/Papes",
	    input1:/^Vatican (\S*) (\d{1,4}\/\d{1,2}\/\d{1,4}-?\d*) (\d+)$/,
	    input2:/^Vatican (\S*) (\d{1,4}\/\d{1,2}\/\d{1,4}-?\d*) (\d+)\-(\d+)$/,
	    nrefs:2,
	    className:"btnVatican",
	    nomenclature:["Vatican", "Dossier", "Date", "article"],
	    source: (doctrines, [_, ref, index]) => doctrines[ref]().then(d => d[index].url),
	    sourceName:"Vatican",
	    fillWithVerses: (dad, verses, doctrines, [_, kind, doctrineIndex]) => {
		doctrines[kind]().then (l => l[doctrineIndex].references).then(refs => {
		    let dad2 = document.createElement("div");
		    let usedRefs = []
		    if (typeof refs == "string") refs = refs.split("\n").map(x => x.trim()).filter(x => x.length != 0).map( str => [str.match(/^\S+/g)[0].replace("(", "[").replace(")", "]"), str] )
		    refs.forEach( ([key, ref]) => {
			if (verses.find(verses2 => verses2.find( v => v.indexOf(key) != -1))){
			    let r = addTextContent(dad2, ref, true)
			    usedRefs.push( [key, r] )
			}
		    })
		    addTextContent(dad, verses, true, usedRefs);
		    usedRefs.forEach( ([_, r]) => dad.appendChild(r))
		})
	    },
	    title:[ undefined,
		    (doctrines, assoc, kind) => kind,
		    (doctrines, doctrine, doctrineIndex) => doctrines[doctrineIndex].title
		  ],
	    access:[undefined,
		    (doctrines, kind) => doctrines[kind](),
		    (assoc, date) => assoc[date]?.text.map(x => x.split("\n"))
		   ],
	    offset: (doctrines, [_, kind, date]) => doctrines[kind]().then(d => d[date].hasIntro ? 0 : 1),
	    index:[
		(doctrines => Object.keys(doctrines)),
		(doctrines, [kind]) => {
		    return doctrines[kind]().then(obj => {
			return Object.entries(obj).map( ([date, x]) => date + " " + x.title) })
		},
		(doctrines, [kind, menuDoctrines]) => doctrines[kind]().then( obj => {
		    let hasIntro = obj[firstWord(menuDoctrines)].hasIntro
		    return obj[firstWord(menuDoctrines)].text.map( (_, i) => hasIntro ? i : i+1)
		})
	    ],
	    compileRef : ( [kind, date, index] ) => "Vatican "+kind+" "+firstWord(date)+" "+index,
	    iterV: async (doctrines, f) => {
		let tab = await Promise.all(Object.entries(doctrines).map(([kind, doc]) => doc().then( ds => Object.entries(ds).map( ([date, doctrine]) => [kind, date, doctrine]))))
		tab.forEach( ds => ds.forEach( ([kind, date, doctrine]) => doctrine.text.forEach( (text, i) => f("Vatican " + kind + " " + date + " " + (doctrine.hasIntro ? i : i+1), text))))
	    },
	    navigation : (assoc, [_, kind, date, versetF, versetT], offset) =>  makenav("Vatican "+kind+" "+date+" ", offset, assoc.length - 1 + offset, versetF, versetT)
	}
    }
}

export { loadDocuments, changeBible, biblesNames };

