# Gate 首页宣传资产

本目录提供可直接用于 Gate 首页或静态托管页面的宣传素材：

- `index.html`：图形化宣传首页（中文）
- `assets/logo-autofix-openclaw.svg`：项目 LOGO
- `assets/graphic-repair-pipeline.svg`：修复流水线图
- `assets/graphic-pain-solution-map.svg`：痛点-方案-结果图

## 本地预览

在仓库根目录运行：

```bash
python3 -m http.server 8787
```

然后访问：

- `http://localhost:8787/marketing/gate-home/index.html`

## 上线建议

1. 直接将 `marketing/gate-home/` 目录部署为静态站点。
2. 首页 LOGO 使用 `assets/logo-autofix-openclaw.svg`。
3. 若需双语版，可在当前 `index.html` 基础上复制出 `index.en.html`。
