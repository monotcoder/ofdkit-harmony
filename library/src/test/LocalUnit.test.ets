import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  AnnotationStore,
  InkAnnotation,
  MetadataDisplayBuilder,
  MetadataDisplayItem,
  PageCoordinateMapper
} from '../main/ets/ofdkit';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('pageCoordinateMapper', 0, () => {
      const mapper: PageCoordinateMapper = new PageCoordinateMapper(
        2,
        { x: 0, y: 0, width: 100, height: 200 },
        { scale: 2, offsetX: 10, offsetY: 20 }
      );

      const viewport = mapper.pageToViewport({ x: 5, y: 10 });
      expect(viewport.x).assertEqual(20);
      expect(viewport.y).assertEqual(40);

      const page = mapper.viewportToPage({ x: 20, y: 40 });
      expect(page.pageIndex).assertEqual(2);
      expect(page.x).assertEqual(5);
      expect(page.y).assertEqual(10);
    });

    it('annotationStoreHitTest', 0, () => {
      const store: AnnotationStore = new AnnotationStore();
      const annotation: InkAnnotation = {
        id: 'a1',
        pageIndex: 0,
        strokes: [
          {
            id: 's1',
            style: { color: '#000000', width: 1 },
            points: [
              { pageIndex: 0, x: 0, y: 0 },
              { pageIndex: 0, x: 10, y: 0 }
            ]
          }
        ],
        metadata: {
          userName: 'Mo',
          createdAt: 1
        }
      };

      store.addAnnotation(annotation);
      const hit = store.hitTest({ pageIndex: 0, x: 5, y: 0.5 }, 1);
      expect(hit !== undefined).assertTrue();
      if (hit !== undefined) {
        expect(hit.id).assertEqual('a1');
      }

      const miss = store.hitTest({ pageIndex: 0, x: 5, y: 5 }, 1);
      expect(miss === undefined).assertTrue();
    });

    it('metadataDisplayBuilder', 0, () => {
      const builder: MetadataDisplayBuilder = new MetadataDisplayBuilder();
      const customData: Map<string, string> = new Map<string, string>();
      customData.set('caseNo', 'A-001');
      const items: MetadataDisplayItem[] = builder.build({
        userName: 'Mo',
        department: '研发部',
        createdAt: 123,
        customData
      }, {
        fields: [
          { key: 'userName', label: '用户' },
          { key: 'caseNo', label: '案件号' },
          { key: 'missing', label: '空字段' },
          { key: 'createdAt', label: '时间' }
        ]
      });

      expect(items.length).assertEqual(3);
      expect(items[0].value).assertEqual('Mo');
      expect(items[1].value).assertEqual('A-001');
      expect(items[2].value).assertEqual('123');
    });
  });
}
