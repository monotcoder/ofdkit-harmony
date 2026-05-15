// 轻量 XML DOM 解析器，按字符流扫描，输出节点树。
// 之所以不用 @ohos.xml：它的属性获取在不同 API 版本行为不一致，且未来抽 ohpm Library 时希望零平台依赖。
// OFD 的 XML 规整、无 DTD/PI 复杂语法，手写一份够用且可控。

export interface XmlNode {
  name: string;
  attrs: Map<string, string>;
  text: string;
  children: XmlNode[];
}

export class XmlParser {
  private input: string = '';
  private pos: number = 0;

  static parse(xml: string): XmlNode {
    const parser: XmlParser = new XmlParser();
    return parser.parseRoot(xml);
  }

  static findChild(node: XmlNode, name: string): XmlNode | undefined {
    for (let i: number = 0; i < node.children.length; i++) {
      if (node.children[i].name === name) {
        return node.children[i];
      }
    }
    return undefined;
  }

  static findChildren(node: XmlNode, name: string): XmlNode[] {
    const result: XmlNode[] = [];
    for (let i: number = 0; i < node.children.length; i++) {
      if (node.children[i].name === name) {
        result.push(node.children[i]);
      }
    }
    return result;
  }

  static attr(node: XmlNode, name: string): string | undefined {
    return node.attrs.get(name);
  }

  static requireAttr(node: XmlNode, name: string): string {
    const value: string | undefined = node.attrs.get(name);
    if (value === undefined) {
      throw new Error(`<${node.name}> 缺少 ${name} 属性`);
    }
    return value;
  }

  static childText(node: XmlNode, name: string): string | undefined {
    const child: XmlNode | undefined = XmlParser.findChild(node, name);
    if (child === undefined) {
      return undefined;
    }
    const text: string = child.text.trim();
    return text.length > 0 ? text : undefined;
  }

  private parseRoot(xml: string): XmlNode {
    this.input = xml;
    this.pos = 0;
    this.skipProlog();
    const root: XmlNode | undefined = this.parseElement();
    if (root === undefined) {
      throw new Error('XML 无根节点');
    }
    return root;
  }

  private skipProlog(): void {
    while (this.pos < this.input.length) {
      this.skipWhitespace();
      if (this.peek('<?')) {
        this.skipUntil('?>');
      } else if (this.peek('<!--')) {
        this.skipUntil('-->');
      } else if (this.peek('<!')) {
        this.skipUntil('>');
      } else {
        break;
      }
    }
  }

  private parseElement(): XmlNode | undefined {
    this.skipWhitespaceAndComments();
    if (!this.peek('<') || this.peek('</')) {
      return undefined;
    }
    this.expect('<');
    const rawName: string = this.readName();
    const attrs: Map<string, string> = this.readAttributes();
    this.skipWhitespace();

    const node: XmlNode = {
      name: this.stripNs(rawName),
      attrs,
      text: '',
      children: []
    };

    if (this.peek('/>')) {
      this.expect('/>');
      return node;
    }
    this.expect('>');

    while (this.pos < this.input.length) {
      if (this.peek('</')) {
        this.expect('</');
        const closeName: string = this.readName();
        this.skipWhitespace();
        this.expect('>');
        if (this.stripNs(closeName) !== node.name) {
          throw new Error(`XML 标签未配对：<${rawName}> 对 </${closeName}>`);
        }
        return node;
      }
      if (this.peek('<![CDATA[')) {
        node.text = node.text + this.readCdata();
        continue;
      }
      if (this.peek('<!--')) {
        this.skipUntil('-->');
        continue;
      }
      if (this.peek('<')) {
        const child: XmlNode | undefined = this.parseElement();
        if (child !== undefined) {
          node.children.push(child);
        }
        continue;
      }
      const chunk: string = this.readTextUntil('<');
      if (chunk.length > 0) {
        node.text = node.text + this.unescape(chunk);
      }
    }
    throw new Error(`XML 标签未闭合：<${rawName}>`);
  }

  private readAttributes(): Map<string, string> {
    const attrs: Map<string, string> = new Map<string, string>();
    while (this.pos < this.input.length) {
      this.skipWhitespace();
      const ch: string = this.input.charAt(this.pos);
      if (ch === '/' || ch === '>') {
        break;
      }
      const rawName: string = this.readName();
      this.skipWhitespace();
      this.expect('=');
      this.skipWhitespace();
      const quote: string = this.input.charAt(this.pos);
      if (quote !== '"' && quote !== '\'') {
        throw new Error(`XML 属性 ${rawName} 缺少引号`);
      }
      this.pos++;
      const start: number = this.pos;
      while (this.pos < this.input.length && this.input.charAt(this.pos) !== quote) {
        this.pos++;
      }
      const rawValue: string = this.input.substring(start, this.pos);
      this.expect(quote);
      attrs.set(this.stripNs(rawName), this.unescape(rawValue));
    }
    return attrs;
  }

  private readName(): string {
    const start: number = this.pos;
    while (this.pos < this.input.length && XmlParser.isNameChar(this.input.charCodeAt(this.pos))) {
      this.pos++;
    }
    if (start === this.pos) {
      throw new Error(`XML 期望名称，位置 ${this.pos}`);
    }
    return this.input.substring(start, this.pos);
  }

  private readCdata(): string {
    this.expect('<![CDATA[');
    const start: number = this.pos;
    const end: number = this.input.indexOf(']]>', start);
    if (end < 0) {
      throw new Error('CDATA 未闭合');
    }
    const value: string = this.input.substring(start, end);
    this.pos = end + 3;
    return value;
  }

  private readTextUntil(stop: string): string {
    const start: number = this.pos;
    const idx: number = this.input.indexOf(stop, start);
    this.pos = idx < 0 ? this.input.length : idx;
    return this.input.substring(start, this.pos);
  }

  private peek(literal: string): boolean {
    return this.input.startsWith(literal, this.pos);
  }

  private expect(literal: string): void {
    if (!this.peek(literal)) {
      throw new Error(`XML 期望 "${literal}"，位置 ${this.pos}`);
    }
    this.pos += literal.length;
  }

  private skipWhitespace(): void {
    while (this.pos < this.input.length) {
      const code: number = this.input.charCodeAt(this.pos);
      if (code === 0x20 || code === 0x09 || code === 0x0A || code === 0x0D) {
        this.pos++;
      } else {
        break;
      }
    }
  }

  private skipWhitespaceAndComments(): void {
    while (this.pos < this.input.length) {
      this.skipWhitespace();
      if (this.peek('<!--')) {
        this.skipUntil('-->');
      } else {
        break;
      }
    }
  }

  private skipUntil(stop: string): void {
    const idx: number = this.input.indexOf(stop, this.pos);
    this.pos = idx < 0 ? this.input.length : idx + stop.length;
  }

  private stripNs(name: string): string {
    const idx: number = name.indexOf(':');
    return idx >= 0 ? name.substring(idx + 1) : name;
  }

  private unescape(text: string): string {
    if (text.indexOf('&') < 0) {
      return text;
    }
    let result: string = '';
    let i: number = 0;
    while (i < text.length) {
      if (text.charAt(i) !== '&') {
        result = result + text.charAt(i);
        i++;
        continue;
      }
      const semi: number = text.indexOf(';', i + 1);
      if (semi < 0) {
        result = result + text.substring(i);
        break;
      }
      const entity: string = text.substring(i + 1, semi);
      const decoded: string | undefined = XmlParser.decodeEntity(entity);
      if (decoded !== undefined) {
        result = result + decoded;
      } else {
        result = result + text.substring(i, semi + 1);
      }
      i = semi + 1;
    }
    return result;
  }

  private static decodeEntity(entity: string): string | undefined {
    if (entity === 'amp') return '&';
    if (entity === 'lt') return '<';
    if (entity === 'gt') return '>';
    if (entity === 'quot') return '"';
    if (entity === 'apos') return '\'';
    if (entity.length >= 2 && entity.charAt(0) === '#') {
      const isHex: boolean = entity.charAt(1) === 'x' || entity.charAt(1) === 'X';
      const numText: string = isHex ? entity.substring(2) : entity.substring(1);
      const code: number = parseInt(numText, isHex ? 16 : 10);
      if (!Number.isNaN(code) && code >= 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
    }
    return undefined;
  }

  private static isNameChar(code: number): boolean {
    if (code >= 0x41 && code <= 0x5A) return true;
    if (code >= 0x61 && code <= 0x7A) return true;
    if (code >= 0x30 && code <= 0x39) return true;
    if (code === 0x5F || code === 0x2D || code === 0x2E || code === 0x3A) return true;
    return code > 0x7F;
  }
}
