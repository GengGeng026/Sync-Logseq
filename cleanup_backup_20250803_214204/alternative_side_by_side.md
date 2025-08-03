# 其他並列顯示方案

## 方案1: HTML Flexbox (當前使用)
```html
<div style="display: flex; gap: 20px; align-items: flex-start;">
  <div style="flex: 1;">
    <img src="./Memory01.png" alt="Memory 01" style="width: 100%; height: auto;">
    <p align="center"><em>Memory 01</em></p>
  </div>
  <div style="flex: 1;">
    <img src="./Memory02.png" alt="Memory 02" style="width: 100%; height: auto;">
    <p align="center"><em>Memory 02</em></p>
  </div>
</div>
```

## 方案2: Markdown 表格
```markdown
| Memory 01 | Memory 02 |
|-----------|-----------|
| ![Memory 01](./Memory01.png) | ![Memory 02](./Memory02.png) |
```

## 方案3: HTML 表格
```html
<table>
  <tr>
    <td width="50%">
      <img src="./Memory01.png" alt="Memory 01" width="100%">
      <p align="center"><em>Memory 01</em></p>
    </td>
    <td width="50%">
      <img src="./Memory02.png" alt="Memory 02" width="100%">
      <p align="center"><em>Memory 02</em></p>
    </td>
  </tr>
</table>
```

## 方案4: 簡單並列 (GitHub 支持)
```markdown
<img src="./Memory01.png" alt="Memory 01" width="45%"> <img src="./Memory02.png" alt="Memory 02" width="45%">
```