// 解析常用的 OFD 数据格式（Box、CTM、Color、数组），供 ContentParser/DocumentParser 复用。

import { CTM, Color, PageBox } from './types';
import { XmlNode, XmlParser } from '../utils/XmlParser';

export class ParseHelpers {
  static box(text: string): PageBox {
    const values: number[] = ParseHelpers.numberArray(text);
    if (values.length !== 4) {
      throw new Error(`Box 格式错误：${text}`);
    }
    return { x: values[0], y: values[1], width: values[2], height: values[3] };
  }

  static optionalBox(text: string | undefined): PageBox | undefined {
    return text === undefined ? undefined : ParseHelpers.box(text);
  }

  static optionalCTM(text: string | undefined): CTM | undefined {
    if (text === undefined) {
      return undefined;
    }
    const values: number[] = ParseHelpers.numberArray(text);
    if (values.length !== 6) {
      console.warn(`[ofdkit] CTM 格式错误：${text}`);
      return undefined;
    }
    return {
      a: values[0],
      b: values[1],
      c: values[2],
      d: values[3],
      e: values[4],
      f: values[5]
    };
  }

  static color(node: XmlNode | undefined): Color | undefined {
    if (node === undefined) {
      return undefined;
    }
    const value: string | undefined = XmlParser.attr(node, 'Value');
    if (value === undefined) {
      return undefined;
    }
    return {
      value,
      alpha: ParseHelpers.optionalNumber(XmlParser.attr(node, 'Alpha'))
    };
  }

  static number(text: string): number {
    const value: number = Number(text);
    if (Number.isNaN(value)) {
      throw new Error(`数值格式错误：${text}`);
    }
    return value;
  }

  static optionalNumber(text: string | undefined): number | undefined {
    if (text === undefined) {
      return undefined;
    }
    const value: number = Number(text);
    return Number.isNaN(value) ? undefined : value;
  }

  static optionalNumberArray(text: string | undefined): number[] | undefined {
    if (text === undefined) {
      return undefined;
    }
    const values: number[] = ParseHelpers.numberArray(text);
    return values.length > 0 ? values : undefined;
  }

  // 解析 OFD ST_Array：除了普通数字，还支持 "g N v" 表示 N 个连续相同值。
  static optionalDeltaArray(text: string | undefined): number[] | undefined {
    if (text === undefined) {
      return undefined;
    }
    const tokens: string[] = text.split(/\s+/).filter((t: string) => t.length > 0);
    const result: number[] = [];
    let i: number = 0;
    while (i < tokens.length) {
      if (tokens[i].toLowerCase() === 'g') {
        const count: number = parseInt(tokens[i + 1], 10);
        const value: number = Number(tokens[i + 2]);
        if (!Number.isNaN(count) && !Number.isNaN(value)) {
          for (let j: number = 0; j < count; j++) {
            result.push(value);
          }
        }
        i += 3;
      } else {
        const v: number = Number(tokens[i]);
        if (!Number.isNaN(v)) {
          result.push(v);
        }
        i++;
      }
    }
    return result.length > 0 ? result : undefined;
  }

  static optionalBoolean(text: string | undefined): boolean | undefined {
    if (text === undefined) {
      return undefined;
    }
    const lower: string = text.toLowerCase();
    return lower === 'true' || lower === '1';
  }

  static numberArray(text: string): number[] {
    return text.split(/\s+/)
      .filter((item: string) => item.length > 0)
      .map((item: string) => Number(item))
      .filter((value: number) => !Number.isNaN(value));
  }
}
