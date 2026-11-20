# 从一个最小 hook 看懂工程

`+[UIImage imageNamed:]` 是类方法，需要对 UIImage 的 metaclass 安装，而不是把它当实例方法处理。

```objc
Class meta = object_getClass(UIImage.class);
Method method = class_getInstanceMethod(meta, @selector(imageNamed:));
IMP old = method_getImplementation(method);
// replacement 必须与原方法参数/返回值完全一致：
// UIImage *replacement(id self, SEL cmd, NSString *name)
if (!class_addMethod(meta, @selector(imageNamed:), replacement,
                     method_getTypeEncoding(method))) {
    old = method_setImplementation(
        class_getInstanceMethod(meta, @selector(imageNamed:)), replacement);
}
```

这段是说明片段，`replacement` 应为正确转换的 IMP；完整可用版本是 `SaoqiangWCAssetsReplace`。先 `class_addMethod` 的原因是 selector 可能继承自父类：直接修改查到的 Method 会把父类也改掉。添加本类 override 成功时，保存的是父类原 IMP；失败时再替换本类已有实现。实例方法则直接传类，例如 UIImageView.class。

替换函数先调用保存的原函数指针并传回原始 `self`、`_cmd`，完整保留返回值。参数多一个、少一个或强制使用不匹配签名都可能破坏调用约定。本工程每个 selector 都有独立类型正确的原函数指针。安装时仍假设没有另一个线程同时改相同 selector；跨插件安装协调不在 runtime API 的保证范围内。

捕获时先检查线程局部 suppression/嵌套深度、自己的 UI 显示状态，再进入 store。store 检查启用和弱指针去重、8 个在途上限，只保留 UIImage 并串行入队。实际读取/渲染不放在 hook 主线程执行。编码线程用 suppression 包住，避免自身 UIImage 创建再次触发捕获；缩略图另有对象关联标记。

`imageNamed:` 不提供真实文件路径，因此不能把渲染 PNG 叫作原文件。文件路径 hook 的后台读取成功才能分享原字节；Assets.car 的解析和 SVG 渲染不在首版范围内。

阅读顺序：`SaoqiangWCAssetsHooks.m` → `SaoqiangWCAssetsStore.m` → `SaoqiangWCAssetsUI.m`。先独立编译/注入测试，再增加 hook；每增加一个 selector 都核对方法类型编码、继承关系和原函数调用。
