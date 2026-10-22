// One pass so a "//" inside a string, or a quote inside a comment, cannot hide code. Line breaks
// are kept, so match offsets still map to source lines.
export function stripCommentsAndStrings(source, keepStrings = false) {
  return source.replace(
    /\/\*[\s\S]*?\*\/|\/\/[^\n]*|'(?:[^'\\\n]|\\.)*'/g,
    (token) => {
      if (token.startsWith("'")) return keepStrings ? token : "''";
      return token.replace(/[^\n]/g, " ");
    }
  );
}

// Inline SOQL, allowing one level of brackets inside it such as a ":ids[0]" bind.
export const inlineSoqlPattern = /\[\s*SELECT\b(?:[^[\]]|\[[^[\]]*\])*\]/gi;

export const lineOf = (source, index) =>
  source.slice(0, index).split("\n").length;
