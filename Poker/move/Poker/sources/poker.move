/*
/// Module: poker
module poker::poker;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions


module poker::poker {
    use sui::object::{UID, Self};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::random::Random;
    use std::vector;

    // 游戏币余额存储，真实balance在这个基础上 除10
    public struct GameStore has key {
        id: UID,
        balances: Table<address, u64>
    }

    // 卡牌结构
    public struct Card has copy, drop {
        value: u8,
        suit: u8
    }

    // 游戏结果事件
    public struct GameResultEvent has copy, drop {
        final_balance: u64,
        winner_region: u8,
        prize: u64,
        cards: vector<Card>
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

    // 初始化存储
    fun init(ctx: &mut TxContext) {
        let store = GameStore {
            id: object::new(ctx),
            balances: table::new(ctx)
        };
        transfer::share_object(store);
    }

    public struct BalanceEvent has copy, drop {
        balances: u64
    }

    // 查询游戏币余额
    public entry fun get_balance(store: &GameStore,  ctx: &mut TxContext){
        let mut coins = 0;
        let addr = tx_context::sender(ctx);
        if (table::contains(&store.balances, addr)) {
            coins = *table::borrow(&store.balances, addr)
        };
        sui::event::emit(BalanceEvent {
            balances: coins
        });
    }

    fun get_balance_internal(store: &GameStore,  ctx: &mut TxContext): u64 {
        let mut coins = 0;
        let addr = tx_context::sender(ctx);
        if (table::contains(&store.balances, addr)) {
            coins = *table::borrow(&store.balances, addr)
        };
        coins
    }

    // 添加游戏币
    public entry fun add_balance(store: &mut GameStore, amount: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let mut final_balance = 0;
        
        if (!table::contains(&store.balances, sender)) {
            table::add(&mut store.balances, sender, amount);
            final_balance = amount;
        } else {
            let balance = table::borrow_mut(&mut store.balances, sender);
            *balance = *balance + amount;
            final_balance = *balance;
        };

        // 余额更新
        sui::event::emit(BalanceEvent {
            balances: final_balance
        });
    }

    // 游戏主逻辑
    public entry fun play_game(
        store: &mut GameStore,
        random: &Random,
        bet_a: u64,
        bet_b: u64,
        bet_c: u64,
        bet_d: u64,
        bet_e: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let total_bet = bet_a + bet_b + bet_c + bet_d + bet_e;
        
        // 检查余额是否足够
        assert!(get_balance_internal(store, ctx) >= total_bet, ERROR_INSUFFICIENT_BALANCE);
        assert!(total_bet > 0, ERROR_INVALID_BET);

        // 扣除下注金额
        let balance = table::borrow_mut(&mut store.balances, sender);
        *balance = *balance - total_bet;

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
            bet_a * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_B) {
            bet_b * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_C) {
            bet_c * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else if (winner == REGION_D) {
            bet_d * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        } else {
            bet_e * PRIZE_MULTIPLIER / PRIZE_DIVIDER
        };

        // 发放奖金
        let balance = table::borrow_mut(&mut store.balances, sender);
        *balance = *balance + prize;
        let mut coins = *balance;

        // 发送事件
        event::emit(GameResultEvent {
            final_balance: coins,
            winner_region: winner,
            prize,
            cards
        });
    }

    // 初始化牌组
    fun init_card_pool(): vector<Card> {
        let suits = vector[SPADE, HEART, CLUB, DIAMOND];
        let mut cards = vector::empty();
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
}