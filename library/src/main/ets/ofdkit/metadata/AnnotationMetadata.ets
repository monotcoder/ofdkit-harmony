// 功能开头：批注元数据承载用户身份、时间和业务字段，支持政企追溯场景。
// 未来计划：加入字段脱敏、签名校验、防篡改摘要和服务端同步标识。
export interface AnnotationMetadata {
  userId?: string;
  userName?: string;
  organization?: string;
  department?: string;
  role?: string;
  businessId?: string;
  createdAt: number;
  updatedAt?: number;
  customData?: Map<string, string>;
}

export interface MetadataDisplayField {
  key: string;
  label: string;
}

export interface MetadataDisplayConfig {
  fields: MetadataDisplayField[];
}
