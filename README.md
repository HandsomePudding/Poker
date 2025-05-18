# Poker Game 扑克牌游戏

## 项目简介 | Project Introduction

**中文**：  
Lucky Poker 是一个基于 Sui 区块链的去中心化扑克游戏，支持 5 区域下注、链上公平发牌、4.8 倍赔率奖励、动画与音效、钱包集成、游戏币兑换、打赏等功能，界面美观，交互流畅。

**English**:  
Lucky Poker is a decentralized poker DApp built on the Sui blockchain. It supports 5 betting regions, on-chain fair dealing, 4.8x payout, smooth animations and sound effects, wallet integration, token swap, donation, and a beautiful UI.

---

## 在线体验 | Online Demo

🌐 [https://poker.hackathon.xin/](https://poker.hackathon.xin/)

---

## 功能特性 | Features

- 5 个下注区域，支持多区域同时下注  
  5 betting regions, multi-region simultaneous betting
- 链上公平发牌，合约自动判定胜负  
  On-chain fair dealing, contract-based winner determination
- 4.8 倍赔率奖励  
  4.8x payout for winners
- Sui 钱包集成，余额实时显示  
  Sui wallet integration, real-time balance display
- 游戏币与 SUI 互换  
  PokerToken ↔ SUI swap
- 筹码动画、音效、下注飞筹、胜负弹窗  
  Chip animation, sound effects, flying chips, result popup
- 打赏功能，支持 SUI 捐赠  
  Donation feature, support SUI tip to project

---

## 游戏规则 | Game Rules

### 基本玩法 | Basic Play

1. **下注区域** - 5 个可选区域 (A-E)  
   ▶ 每个区域独立下注，支持多区域同时下注  
   ▶ 5 betting regions (A-E), each can be bet independently

2. **牌型比较 | Card Comparison**

   | Card type | weight |  
      |--|---|  
   | A | 14 |  
   | K-Q-J-10-2 | 13-2 |
   | Spade(♠)>Heart(♥)>Club(♣)>Diamond(♦) | 4>3>2>1 |

3. **奖励机制 | Reward**  
   获胜赔率 = 下注金额 × 4.8  
   Winner payout = Bet × 4.8

---

## 本地部署 | Local Deployment

```bash
git clone https://github.com/HandsomePudding/Poker.git
cd Poker
npm install --legacy-peer-deps
npm run dev
```

---

## 打赏功能 | Donation

- 点击页面右下角 Donate 按钮，可通过 SUI 向项目合约打赏支持开发者。
- Click the Donate button to tip the project with SUI.

---


## 视频介绍 | Video Introduction

- https://youtu.be/V8JO6N03lSM

---

