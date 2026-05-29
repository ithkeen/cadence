# 什么时候 mock

只在**系统边界**上 mock：

- 外部 API（支付、邮件等）
- 数据库（偶尔需要——优先用测试数据库替代）
- 时间 / 随机数
- 文件系统（偶尔需要）

不要 mock：

- 你自己的类 / 模块
- 内部协作者
- 任何你能控制的东西

## 让接口好 mock

在系统边界上，把接口设计得方便 mock：

**1. 用依赖注入**

把外部依赖传进来，不要在内部创建：

```typescript
// 容易 mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// 难以 mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. 优先用 SDK 风格的接口，不要写通用 fetcher**

为每个外部操作各自写一个具体函数，而不是写一个带条件分支的通用函数：

```typescript
// 好：每个函数都可以独立 mock
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// 坏：mock 时需要在 mock 内部写条件分支
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

这种 SDK 风格意味着：

- 每个 mock 返回一种确定形状
- 测试 setup 里没有条件分支
- 一眼能看出某个测试用到了哪些端点
- 每个端点都能有自己的类型安全
