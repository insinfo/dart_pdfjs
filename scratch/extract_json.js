const fs = require('fs');

function extract(filename) {
  let content = fs.readFileSync(filename, 'utf8');
  content = content.replace(/import .*/g, '');
  content = content.replace(/export \{[\s\S]*?\};?/g, '');
  
  const prefix = `
    function getLookupTableFactory(cb) {
      let t = {};
      cb(t);
      return t;
    }
  `;
  
  const suffix = `
    return {
      getStdFontMap: typeof getStdFontMap !== 'undefined' ? getStdFontMap : null,
      getFontNameToFileMap: typeof getFontNameToFileMap !== 'undefined' ? getFontNameToFileMap : null,
      getNonStdFontMap: typeof getNonStdFontMap !== 'undefined' ? getNonStdFontMap : null,
      getSerifFonts: typeof getSerifFonts !== 'undefined' ? getSerifFonts : null,
      getSymbolsFonts: typeof getSymbolsFonts !== 'undefined' ? getSymbolsFonts : null,
      getGlyphMapForStandardFonts: typeof getGlyphMapForStandardFonts !== 'undefined' ? getGlyphMapForStandardFonts : null,
      getMetrics: typeof getMetrics !== 'undefined' ? getMetrics : null
    };
  `;
  
  const fn = new Function(prefix + content + suffix);
  return fn();
}

try {
  const stdFonts = extract('referencia/pdf.js-master/src/core/standard_fonts.js');
  fs.writeFileSync('scratch/standard_fonts.json', JSON.stringify(stdFonts, null, 2));

  const metrics = extract('referencia/pdf.js-master/src/core/metrics.js');
  fs.writeFileSync('scratch/metrics.json', JSON.stringify(metrics, null, 2));
  console.log("JSONs extraidos com sucesso");
} catch(e) {
  console.error("Erro extraindo:", e);
}
