/*
/// Module: poker
module poker::poker;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions


module poker::POKERTOEN {
    use sui::object::{UID, Self};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::random::Random;
    use std::vector;
    use sui::balance::{Self, Balance, Supply};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::package::Publisher;
    use sui::url;

    // 游戏币余额存储，真实balance在这个基础上 除10
    public struct PokerGame has key {
        id: UID,
        pool: Balance<SUI>
    }

    // 卡牌结构
    public struct Card has copy, drop {
        value: u8,
        suit: u8
    }

    // 游戏结果事件
    public struct GameResultEvent has copy, drop {
        winner_region: u8,
        cards: vector<Card>
    }

    public struct POKERTOEN has drop {}

    public struct PokerTreasuryCap has key {
        id: UID,
        supply: Supply<POKERTOEN>
    }

    public struct AdminCap has key {
        id : UID
    }

    // 常量定义
    const PRIZE_MULTIPLIER: u64 = 48;
    const PRIZE_DIVIDER: u64 = 10;

    // 游戏区域定义
    const REGION_A: u8 = 0;
    const REGION_B: u8 = 1;
    const REGION_C: u8 = 2;
    const REGION_D: u8 = 3;
    const REGION_E: u8 = 4;

    // 牌面花色定义
    const SPADE: u8 = 4;   // 黑桃
    const HEART: u8 = 3;   // 红桃
    const CLUB: u8 = 2;    // 梅花
    const DIAMOND: u8 = 1; // 方片

    // 错误码
    const ERROR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERROR_INVALID_BET: u64 = 2;

    const TOKEN_EXCHANGE_RATE: u64 = 100; // 1 SUI = 100 POKERTOEN
    const SUI_DECIMALS: u64 = 1_000_000_000;
    const POKER_DECIMALS: u64 = 10;

    // 初始化存储
    fun init(token: POKERTOEN, ctx: &mut TxContext) {
        // 创建代币
        let (treasury, metadata) = coin::create_currency(
            token,
            1,
            b"Poker",
            b"POKERTOEN",
            b"The official currency of the Poker Game",
            option::some(url::new_unsafe_from_bytes(b"https://hackathon.oss-cn-beijing.aliyuncs.com/pokerToken.png")),
            ctx
        );

        transfer::public_freeze_object(metadata);

        let store = PokerGame {
            id: object::new(ctx),
            pool: balance::zero<SUI>()
        };
        transfer::share_object(store);

        let admin = AdminCap{
            id : object::new(ctx)
        };
        transfer::transfer(admin, ctx.sender());

        // 创建代币控制权
        let treasury_cap = PokerTreasuryCap {
            id: object::new(ctx),
            supply: coin::treasury_into_supply(treasury)
        };
        transfer::share_object(treasury_cap);
    }


    // 玩家购买代币
    public entry fun buy_poker_tokens(
        treasury: &mut PokerTreasuryCap,
        game: &mut PokerGame,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let sui_amount = coin::value(&payment);
        assert!(sui_amount > 0, 0);

        // 全部转入奖池
        balance::join(&mut game.pool, coin::into_balance(payment));

        // 铸造代币（1 SUI = 100 Token）
        let token_amount = sui_amount * TOKEN_EXCHANGE_RATE * POKER_DECIMALS / SUI_DECIMALS;
        let tokens = mint(treasury, token_amount, ctx);

        // 直接转给玩家
        transfer::public_transfer(tokens, tx_context::sender(ctx));
    }

    // 卖出代币（100 POKERTOEN = 1 SUI）
    public entry fun sell_tokens(
        treasury: &mut PokerTreasuryCap,
        game: &mut PokerGame,
        tokens: Coin<POKERTOEN>,
        ctx: &mut TxContext
    ) {
        let token_amount = coin::value(&tokens);
        assert!(token_amount > 0, 10);

        // 计算可兑换的SUI数量
        let sui_amount = token_amount * SUI_DECIMALS / TOKEN_EXCHANGE_RATE / POKER_DECIMALS;
        assert!(balance::value(&game.pool) >= sui_amount, 11);

        // 销毁玩家代币
        burn(treasury, coin::into_balance(tokens));

        // 从奖池提取SUI给玩家
        let sui_coin = coin::from_balance(
            balance::split(&mut game.pool, sui_amount),
            ctx
        );
        transfer::public_transfer(sui_coin, tx_context::sender(ctx));
    }

    // 铸造代币
    fun mint(
        treasury: &mut PokerTreasuryCap,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<POKERTOEN> {
        coin::from_balance(
            balance::increase_supply(&mut treasury.supply, amount),
            ctx
        )
    }


    fun burn(treasury: &mut PokerTreasuryCap, balance: Balance<POKERTOEN>): u64 {
        treasury.supply.decrease_supply(balance)
    }

    // 管理员提现
    public entry fun withdraw_pool(
        _: &AdminCap,
        treasury: &mut PokerTreasuryCap,
        game: &mut PokerGame,
        ctx: &mut TxContext
    ) {
        let supply = treasury.supply.supply_value();
        let count = supply * SUI_DECIMALS / TOKEN_EXCHANGE_RATE / POKER_DECIMALS;
        let amount = if (game.pool.value() > count) game.pool.value() - count else 0;
        if(amount > 0){
            let sui_coin = coin::from_balance(
                balance::split(&mut game.pool, amount),
                ctx
            );
            transfer::public_transfer(sui_coin, ctx.sender());
        }
    }

    // 游戏主逻辑
    public entry fun play_game(
        treasury: &mut PokerTreasuryCap,
        game: &mut PokerGame,
        random: &Random,
        bet_a: Coin<POKERTOEN>,
        bet_b: Coin<POKERTOEN>,
        bet_c: Coin<POKERTOEN>,
        bet_d: Coin<POKERTOEN>,
        bet_e: Coin<POKERTOEN>,
        ctx: &mut TxContext
    ) {
        let bet_a_value = coin::value(&bet_a);
        let bet_b_value = coin::value(&bet_b);
        let bet_c_value = coin::value(&bet_c);
        let bet_d_value = coin::value(&bet_d);
        let bet_e_value = coin::value(&bet_e);

        let total_bet = bet_a_value + bet_b_value + bet_c_value + bet_d_value + bet_e_value;
        assert!(total_bet > 0, 2);

        // 销毁下注的 POKERTOEN
        burn(treasury, coin::into_balance(bet_a));
        burn(treasury, coin::into_balance(bet_b));
        burn(treasury, coin::into_balance(bet_c));
        burn(treasury, coin::into_balance(bet_d));
        burn(treasury, coin::into_balance(bet_e));

        // 抽牌
        let cards = draw_unique_cards(random, ctx);
        let card_a = *vector::borrow(&cards, (REGION_A as u64));
        let card_b = *vector::borrow(&cards, (REGION_B as u64));
        let card_c = *vector::borrow(&cards, (REGION_C as u64));
        let card_d = *vector::borrow(&cards, (REGION_D as u64));
        let card_e = *vector::borrow(&cards, (REGION_E as u64));

        // 比较确定获胜区域
        let winner = compare_five_cards(card_a, card_b, card_c, card_d, card_e);

        // 计算奖金
        let prize = if (winner == REGION_A) {
            bet_a_value * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_B) {
            bet_b_value * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_C) {
            bet_c_value * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_D) {
            bet_d_value * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else {
            bet_e_value * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        };

        // 发奖
        if (prize > 0) {
            let prize_tokens = mint(treasury, prize, ctx);
            transfer::public_transfer(prize_tokens, tx_context::sender(ctx));
        };

        // 发送事件
        event::emit(GameResultEvent {
            winner_region: winner,
            cards
        })
    }

    // 初始化牌组
    fun init_card_pool(): vector<Card> {
        let suits = vector[SPADE, HEART, CLUB, DIAMOND];
        let mut cards = std::vector::empty();
        let mut i = 0;
        while (i < vector::length(&suits)) {
            let mut j = 2; // 从2开始，A最大
            while (j <= 14) { // A=14
                let value = if (j == 14) { 1 } else { j };
                vector::push_back(&mut cards, Card { 
                    value, 
                    suit: *vector::borrow(&suits, i) 
                });
                j = j + 1;
            };
            i = i + 1;
        };
        cards
    }

    // 抽五张不重复的牌
    fun draw_unique_cards(random: &Random, ctx: &mut TxContext): vector<Card> {
        let all_cards = init_card_pool();
        let mut cards = vector::empty();
        let mut indices = vector::empty();
        let mut generator = random.new_generator(ctx);

        while (vector::length(&cards) < 5) {
            let max_index = (vector::length(&all_cards) as u64) - 1;
            let index = generator.generate_u64_in_range(0, max_index);
            
            if (!vector::contains(&indices, &index)) {
                vector::push_back(&mut indices, index);
                vector::push_back(&mut cards, *vector::borrow(&all_cards, index));
            };
        };
        cards
    }

    // 比较五张牌
    fun compare_five_cards(a: Card, b: Card, c: Card, d: Card, e: Card): u8 {
        // 先比较前两张
        let ab_winner = if (compare_card_value(a, b)) { REGION_A } else { REGION_B };
        let stronger = if (ab_winner == REGION_A) a else b;
        
        // 与第三张比较
        let abc_winner = if (compare_card_value(stronger, c)) { ab_winner } else { REGION_C };
        let stronger = if (abc_winner == REGION_C) c else stronger;
        
        // 与第四张比较
        let abcd_winner = if (compare_card_value(stronger, d)) { abc_winner } else { REGION_D };
        let stronger = if (abcd_winner == REGION_D) d else stronger;
        
        // 最后与第五张比较
        if (compare_card_value(stronger, e)) {
            abcd_winner
        } else {
            REGION_E
        }
    }

    // 比较单张牌
    fun compare_card_value(a: Card, b: Card): bool {
        let weight_a = get_card_weight(a.value);
        let weight_b = get_card_weight(b.value);
        
        if (weight_a != weight_b) {
            weight_a > weight_b
        } else {
            a.suit > b.suit
        }
    }

    // 牌面权重
    fun get_card_weight(value: u8): u8 {
        if (value == 1) { 14 } else { value } // A的value是1，但权重是14
    }

    // 打赏
    public entry fun reward(game: &mut PokerGame, payment: Coin<SUI>) {
        game.pool.join(payment.into_balance());
    }
}