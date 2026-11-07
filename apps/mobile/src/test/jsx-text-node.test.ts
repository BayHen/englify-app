import { describe, expect, it } from 'vitest';
import ts from 'typescript';

// An empty string or zero returned by JSX `&&` becomes a text child of View on web.
describe('React Native JSX children', () => {
  it('does not return string or number from conditional element rendering', () => {
    const configPath = ts.findConfigFile(process.cwd(), ts.sys.fileExists, 'tsconfig.json');
    if (!configPath) throw new Error('Mobile tsconfig.json not found');
    const config = ts.readConfigFile(configPath, ts.sys.readFile);
    if (config.error) throw new Error(ts.flattenDiagnosticMessageText(config.error.messageText, '\n'));
    const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, process.cwd());
    const program = ts.createProgram(parsed.fileNames, parsed.options);
    const checker = program.getTypeChecker();
    const violations: string[] = [];
    for (const file of program.getSourceFiles()) {
      if (!/[\\/]src[\\/]/.test(file.fileName) || !file.fileName.endsWith('.tsx')) continue;
      const visit = (node: ts.Node) => {
        if (ts.isJsxExpression(node) && node.expression && ts.isBinaryExpression(node.expression) && node.expression.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken) {
          const container = node.parent;
          const tag = ts.isJsxElement(container) ? container.openingElement.tagName.getText(file) : '';
          if (tag !== 'Text' && tag !== 'AppText') {
            const left = checker.getTypeAtLocation(node.expression.left);
            const parts = left.isUnion() ? left.types : [left];
            if (parts.some((part) => Boolean(part.flags & (ts.TypeFlags.StringLike | ts.TypeFlags.NumberLike)))) {
              const line = file.getLineAndCharacterOfPosition(node.getStart(file)).line + 1;
              violations.push(`${file.fileName.replace(process.cwd(), '')}:${line}`);
            }
          }
        }
        ts.forEachChild(node, visit);
      };
      visit(file);
    }
    expect(violations, 'Use !!value, a comparison, or a ternary returning null in JSX').toEqual([]);
  });
});
