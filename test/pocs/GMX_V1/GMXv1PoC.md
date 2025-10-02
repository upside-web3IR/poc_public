# Attack Flow

- **취약점 핵심**: GMX V1의 executeDecreaseOrder 실행 중 **콜백/수신 훅을 통한 재진입(reentrancy)**이 가능하고, 그 사이에 **글로벌 숏 평균가(globalShortAveragePrice)** 및 **AUM/GLP 가격**을 **의도적으로 유리하게 왜곡.**
- **전술**:
  1. ETH 포지션을 열고,
  2. ETH 포지션 **청산(decrease)** 실행 중 콜백/수신 훅을 이용해 **BTC 숏 포지션을 거대하게 조작**하고,
  3. **keeper 가격 업데이트 실행**으로 큐에 쌓인 주문들을 원하는 가격으로 체결시켜 **글로벌 숏 평균가를 흔듦**,
  4. 그 결과 왜곡된 AUM/GLP 가격을 이용해 **GLP 민트/상환으로 금고 토큰을 털어냄**.

# **구성요소(인터페이스/주소)**

- IOrderManager, ITradeExecutor, IPositionHandler : 주문 생성/실행(keeper가 실행)
- ITradingVault : 포지션/금고 상태, increasePosition/decreasePosition
- ILiquidityManager : AUM, 글로벌 숏 평균가 조회
- IPriceFeedManager : **keeper가 가격비트 세팅 + 주문 일괄 실행**
- ILiquidityProvider : GLP **민트/상환**
- fallback() / gmxPositionCallback(...) : **재진입 트리거 포인트**

# **실행 흐름 (함수별)**

## 1. setting

```go
setUp() -> initializeTest()
```

- Arbitrum 포크 고정, 토큰 지급, 각 모듈 approve.

## 2. 메인 시나리오

```go
function testExploit()
```

1. **전/후 금고 잔액 로깅**: 영향 눈으로 확인.
2. **ETH 레버리지 롱 2회 개시**
   - openLeveragedEthPosition() : createIncreaseOrder로 ETH 롱 주문 생성
   - executeEthPositionOpening() : keeper 주소(ORDER_KEEPER)로 executeIncreaseOrder 실행 → 포지션 체결
3. **기준선 출력**: 조작 전 BTC 글로벌 숏 평균가 로깅
4. **조작 단계**
   - createEthPositionClosure() : **ETH 포지션 절반 청산** 주문 생성 (createDecreaseOrder)
   - 루프 5회:
     - executeEthPositionClosure() : **여기가 핵심**. keeper가
       - **tradeExecutor.executeDecreaseOrder(...)**를 실행
         → **실행 중 우리 컨트랙트로 콜백/자금 전송이 발생**
         → **gmxPositionCallback / fallback 재진입**이 터짐
     - executeBtcPositionManipulation() : keeper 주소(POSITION_KEEPER)로
       priceFeedManager.setPricesWithBitsAndExecute(...) 호출
       → **가격 비트를 지정**하고 **증가/감소 큐를 원하는 인덱스까지 실행**
       → 방금 재진입으로 쌓인 주문들을 **의도한 가격**에 체결시켜
       **글로벌 숏 평균가**를 공격자에게 유리하게 **밀어 올리거나 내림**
5. **이익 실현 단계**
   - executeProfit = true
   - 다시 한 번 executeEthPositionClosure() 호출
     → 이번엔 재진입 시 **fallback()이 drainProtocolFunds()를 실행**하여 본격적인 **자금 인출**을 수행
6. **후 상태 로깅**

# 재진입 트리거 지점

## 1. ETH 감소 주문 실행

```go
function executeEthPositionClosure() public {
    vm.startPrank(ORDER_KEEPER);
    tradeExecutor.executeDecreaseOrder(
        address(this),
        orderManager.decreaseOrdersIndex(address(this)) - 1,
        payable(ORDER_KEEPER)
    );
    vm.stopPrank();
}
```

- keeper가 **감소 주문 실행**. 이 실행 **중**에 GMX V1는
  - **콜백(gmxPositionCallback) 호출**
  - **수익 전송/정산 과정에서 우리 컨트랙트에 ETH/토큰 전송 → fallback() 실행**
- 이 두 훅으로 **현재 트랜잭션 컨텍스트** 안에서 **재진입 가능**.

## 2. callback 재귀적 감소 주문 생성

```go
function gmxPositionCallback(...) external {
    createEthPositionClosure(); // 감소 주문 또 쌓음 (재진입 중)
}
```

- 실행 중에 **다시 decrease 주문을 쌓아** 큐를 부풀림

이후 keeper의 일괄 실행에서 **여러 번** 체결될 재료가 됨

## **3. fallback() – 조작 파트 & 이익 실현 파트**

```go
fallback() external payable {
    if (executeProfit) {
        drainProtocolFunds(); // 최종 인출
    } else {
        // (1) 금고에 USDC 주입
        usdcToken.transfer(address(tradingVault), balance)
        // (2) 거대한 BTC 숏 포지션 열기
        tradingVault.increasePosition(... WBTC, isLong=false)
        // (3) 바로 BTC 감소 주문 큐에 쌓기(높은 트리거) – 나중에 일괄 실행
        positionHandler.createDecreasePosition(... WBTC short ...)
    }
}
```

- **이 시점은 아직 executeDecreaseOrder 트랜잭션 내부**
- 공격자는 **중간에 금고 유동성/포지션 상태를 크게 흔들고**
  **“곧 실행될 감소 주문”을 쌓아 둔 뒤** 트랜잭션 흐름으로 복귀

# 가격, 주문 일괄 상태 실행 → 상태 왜곡

```go
function executeBtcPositionManipulation() public {
    (incStart, incCnt, decStart, decCnt) = positionHandler.getRequestQueueLengths();
    vm.startPrank(POSITION_KEEPER);
    priceFeedManager.setPricesWithBitsAndExecute(
        priceBits, block.timestamp,
        incStart + incCnt, decStart + decCnt,
        incCnt, decCnt
    );
    vm.stopPrank();
}
```

- keeper 권한으로 **가격 비트(oracle 입력)를 지정**하고
  현재 쌓여있는 **증가/감소 주문을 한꺼번에 실행(endIdx 지정)**.
- 이렇게 하면 **바로 직전에 재진입 중 쌓았던 주문들**이
  **공격자가 원하는 시세로** 체결되며,
  **글로벌 숏 평균가**(예: WBTC)가 공격자에게 유리하게 **이동**합니다.
- **결과**: AUM/GLP 평가식이 **일시적으로 왜곡** → 이후 GLP 상환 시 **과대 상환** 발생.

# 최종 인출

executeProfit = true 후 재진입하면 여기로 진입.

핵심 단계:

1. **플래시론 시뮬레이션**: deal로 USDC 확보
2. **GLP 민트 & 스테이크**: mintAndStakeGlp(USDC)
3. **추가로 금고에 USDC 예치 + WBTC 대형 숏 오픈**
4. **extractTokenProfits(token) 반복**

```go
available = poolAmounts - reservedAmounts;
usdg = available * price(1e30) / 10^decimals / 1e12; // 1e18 정규화
glpOut = usdg * totalGlpSupply / totalAumUsdg;
unstakeAndRedeemGlp(token, glpOut, 0, this);
```

- **왜곡된 AUM**과 **GLP 비율**을 이용해,
  금고 내 토큰별 **청산 가능한 최대치**를 계산 후 **상환**
  → 풀에서 **토큰 직접 인출**

1. **숏 포지션 정리(decreasePosition)**
2. **반복 루프(여러 토큰/여러 차례)**로 최대 추출
3. **플래시론 상환** 후 **남은 잔액 = 공격자 이득**

# **왜 이게 가능한가**

1. **주문 실행 중 재진입 허용**:

   executeDecreaseOrder 경로에서 **콜백/수신 훅**을 통한 **동 트랜잭션 재진입**이 가능했음.

2. **주문 큐 + keeper 일괄 실행 구조**:

   재진입 중 **새 decrease/increase 주문을 쌓아두고**,

   곧바로 **keeper가 원하는 가격으로 일괄 실행** →

   **글로벌 숏 평균가 / AUM**을 **의도한 방향으로 이동**.

3. **AUM/GLP 상환 수학의 타이밍 결함**:

   상태가 **일관되게 동결되지 않은 채** 여러 모듈(포지션, 가격, AUM, 상환)이

   **부분적으로 갱신**되며, 짧은 창구에서 **GLP 상환이 과대 계산**.
