# 面向可测试性的接口设计

好的接口让测试变得自然：

1. **接收依赖，不要自己创建**

   ```typescript
   // 可测
   function processOrder(order, paymentGateway) {}

   // 难测
   function processOrder(order) {
     const gateway = new StripeGateway();
   }
   ```

2. **返回结果，不要产生副作用**

   ```typescript
   // 可测
   function calculateDiscount(cart): Discount {}

   // 难测
   function applyDiscount(cart): void {
     cart.total -= discount;
   }
   ```

3. **表面积要小**
   - 方法越少 = 要写的测试越少
   - 参数越少 = 测试 setup 越简单
