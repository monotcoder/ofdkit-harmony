import { AnnotationMetadata, MetadataDisplayConfig, MetadataDisplayField } from './AnnotationMetadata';

export interface MetadataDisplayItem {
  key: string;
  label: string;
  value: string;
}

// 功能开头：把批注元数据按客户配置转换成可展示字段，UI 可用 Toast、气泡或弹窗承载。
// 未来计划：加入日期格式本地化、字段脱敏、空值策略和自定义 formatter。
export class MetadataDisplayBuilder {
  static defaultConfig(): MetadataDisplayConfig {
    return {
      fields: [
        { key: 'userName', label: '用户' },
        { key: 'department', label: '部门' },
        { key: 'role', label: '角色' },
        { key: 'businessId', label: '业务ID' },
        { key: 'createdAt', label: '时间' }
      ]
    };
  }

  build(metadata: AnnotationMetadata, config: MetadataDisplayConfig): MetadataDisplayItem[] {
    const items: MetadataDisplayItem[] = [];
    config.fields.forEach((field: MetadataDisplayField) => {
      const item: MetadataDisplayItem | undefined = this.buildItem(metadata, field);
      if (item !== undefined) {
        items.push(item);
      }
    });
    return items;
  }

  private buildItem(metadata: AnnotationMetadata, field: MetadataDisplayField): MetadataDisplayItem | undefined {
    const value: string | undefined = this.valueFor(metadata, field.key);
    if (value === undefined || value.length === 0) {
      return undefined;
    }

    return {
      key: field.key,
      label: field.label,
      value
    };
  }

  private valueFor(metadata: AnnotationMetadata, key: string): string | undefined {
    if (key === 'userId') {
      return metadata.userId;
    }
    if (key === 'userName') {
      return metadata.userName;
    }
    if (key === 'organization') {
      return metadata.organization;
    }
    if (key === 'department') {
      return metadata.department;
    }
    if (key === 'role') {
      return metadata.role;
    }
    if (key === 'businessId') {
      return metadata.businessId;
    }
    if (key === 'createdAt') {
      return `${metadata.createdAt}`;
    }
    if (key === 'updatedAt' && metadata.updatedAt !== undefined) {
      return `${metadata.updatedAt}`;
    }
    if (metadata.customData !== undefined) {
      return metadata.customData.get(key);
    }
    return undefined;
  }
}
