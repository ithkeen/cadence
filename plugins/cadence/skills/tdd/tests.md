# 好测试与坏测试

## 好测试

**集成风格**：通过真实接口测试，不要 mock 内部部件。

```typescript
// 好：测的是可观察行为
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

特征：

- 测的是用户/调用方在意的行为
- 只走公共 API
- 能在内部重构中存活
- 描述的是 WHAT，不是 HOW
- 一个测试只对应一个逻辑断言

## 坏测试

**实现细节测试**：与内部结构耦合。

```typescript
// 坏：测的是实现细节
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

危险信号：

- mock 内部协作者
- 测试私有方法
- 断言调用次数 / 调用顺序
- 重构时行为没变，测试却挂了
- 测试名描述的是 HOW 而不是 WHAT
- 绕过接口走外部手段去验证

```typescript
// 坏：绕过接口去验证
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// 好：透过接口去验证
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```
