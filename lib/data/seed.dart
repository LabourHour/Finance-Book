import 'models.dart';

/// 播种数据：默认分类与默认正式账户用于首次启动；
/// [sampleAccounts] / [createSampleTransactions] 仅作为测试夹具，启动路径不得调用。
class DataSeed {
  static const List<Category> defaultCategories = <Category>[
    Category(
      id: 'cat_dining',
      name: '餐饮美食',
      type: TransactionType.expense,
      symbolText: '餐',
      colorHex: '#D97757',
      isPinned: true,
      order: 1,
    ),
    Category(
      id: 'cat_transport',
      name: '交通出行',
      type: TransactionType.expense,
      symbolText: '行',
      colorHex: '#5B88A5',
      isPinned: true,
      order: 2,
    ),
    Category(
      id: 'cat_shopping',
      name: '日常购物',
      type: TransactionType.expense,
      symbolText: '购',
      colorHex: '#5B9B88',
      isPinned: true,
      order: 3,
    ),
    Category(
      id: 'cat_entertainment',
      name: '休闲娱乐',
      type: TransactionType.expense,
      symbolText: '乐',
      colorHex: '#7E72A6',
      order: 4,
    ),
    Category(
      id: 'cat_rent',
      name: '房租租金',
      type: TransactionType.expense,
      symbolText: '房',
      colorHex: '#9E9B93',
      isFixedExpense: true,
      order: 5,
    ),
    Category(
      id: 'cat_daily',
      name: '生活日用',
      type: TransactionType.expense,
      symbolText: '用',
      colorHex: '#C98B3E',
      isPinned: true,
      order: 6,
    ),
    Category(
      id: 'cat_medical',
      name: '医疗健康',
      type: TransactionType.expense,
      symbolText: '医',
      colorHex: '#BF6B7B',
      order: 7,
    ),
    Category(
      id: 'cat_other',
      name: '其他杂项',
      type: TransactionType.expense,
      symbolText: '他',
      colorHex: '#8C867A',
      order: 8,
    ),
    Category(
      id: 'cat_salary',
      name: '薪资酬劳',
      type: TransactionType.income,
      symbolText: '薪',
      colorHex: '#2F7D52',
      isPinned: true,
      order: 9,
    ),
    Category(
      id: 'cat_invest',
      name: '理财收益',
      type: TransactionType.income,
      symbolText: '理',
      colorHex: '#5B88A5',
      isPinned: true,
      order: 10,
    ),
    Category(
      id: 'cat_sideline',
      name: '外包兼职',
      type: TransactionType.income,
      symbolText: '职',
      colorHex: '#C98B3E',
      order: 11,
    ),
  ];

  /// 账户表为空时唯一的正式账户，保证新用户启动即有账户可用。
  static const Account defaultAccount = Account(
    id: 'acc_cash',
    name: '现金',
    type: AccountType.cash,
    initialBalance: 0,
    symbolText: '现',
    colorHex: '#7E72A6',
    order: 1,
  );

  /// 示例账户与示例流水仅用于测试夹具，不得在启动路径调用。
  static const List<Account> sampleAccounts = <Account>[
    Account(
      id: 'acc_wechat',
      name: '微信零钱',
      type: AccountType.wechat,
      initialBalance: 158050,
      symbolText: '微',
      colorHex: '#07C160',
      order: 1,
      isSample: true,
    ),
    Account(
      id: 'acc_alipay',
      name: '支付宝',
      type: AccountType.alipay,
      initialBalance: 684000,
      symbolText: '支',
      colorHex: '#1677FF',
      order: 2,
      isSample: true,
    ),
    Account(
      id: 'acc_bank',
      name: '招商储蓄卡',
      type: AccountType.bank,
      initialBalance: 3850000,
      symbolText: '招',
      colorHex: '#D97757',
      order: 3,
      isSample: true,
    ),
    Account(
      id: 'acc_credit',
      name: '招行信用卡',
      type: AccountType.credit,
      initialBalance: -245000,
      symbolText: '卡',
      colorHex: '#C0463F',
      order: 4,
      isSample: true,
    ),
    Account(
      id: 'acc_cash',
      name: '随身现金',
      type: AccountType.cash,
      initialBalance: 40000,
      symbolText: '现',
      colorHex: '#8C867A',
      order: 5,
      isSample: true,
    ),
  ];

  static List<LedgerTransaction> createSampleTransactions() {
    final now = DateTime.now();
    final createdAt = now.millisecondsSinceEpoch;

    int timeAgo(int daysAgo, int hour, int minute) => DateTime(
          now.year,
          now.month,
          now.day - daysAgo,
          hour,
          minute,
        ).millisecondsSinceEpoch;

    LedgerTransaction sample({
      required TransactionType type,
      required int amount,
      required String accountId,
      String? toAccountId,
      String? categoryId,
      required int occurredAt,
      String? note,
    }) =>
        LedgerTransaction(
          id: newId(),
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: categoryId,
          occurredAt: occurredAt,
          note: note,
          source: TransactionSource.manual,
          isSample: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

    return <LedgerTransaction>[
      // 今天
      sample(
        type: TransactionType.expense,
        amount: 3600,
        accountId: 'acc_wechat',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(0, 12, 30),
        note: '日式烧肉饭午餐',
      ),
      sample(
        type: TransactionType.expense,
        amount: 1800,
        accountId: 'acc_wechat',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(0, 9, 15),
        note: '燕麦拿铁',
      ),
      sample(
        type: TransactionType.expense,
        amount: 700,
        accountId: 'acc_wechat',
        categoryId: 'cat_transport',
        occurredAt: timeAgo(0, 8, 40),
        note: '地铁通勤',
      ),
      // 昨天
      sample(
        type: TransactionType.expense,
        amount: 12850,
        accountId: 'acc_alipay',
        categoryId: 'cat_shopping',
        occurredAt: timeAgo(1, 19, 45),
        note: '超市日用品与鲜奶',
      ),
      sample(
        type: TransactionType.expense,
        amount: 4500,
        accountId: 'acc_alipay',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(1, 18, 30),
        note: '牛肉煲仔饭',
      ),
      // 2 天前（转账：还信用卡）
      sample(
        type: TransactionType.transfer,
        amount: 150000,
        accountId: 'acc_bank',
        toAccountId: 'acc_credit',
        occurredAt: timeAgo(2, 10, 0),
        note: '储蓄卡自动还信用卡',
      ),
      sample(
        type: TransactionType.expense,
        amount: 8600,
        accountId: 'acc_credit',
        categoryId: 'cat_entertainment',
        occurredAt: timeAgo(2, 15, 20),
        note: '周末电影票 2 张',
      ),
      // 3 天前
      sample(
        type: TransactionType.expense,
        amount: 3200,
        accountId: 'acc_wechat',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(3, 12, 10),
        note: '公司园区食堂',
      ),
      // 5 天前（固定大额房租支出）
      sample(
        type: TransactionType.expense,
        amount: 450000,
        accountId: 'acc_bank',
        categoryId: 'cat_rent',
        occurredAt: timeAgo(5, 14, 0),
        note: '11月整租房租 (固定支出)',
      ),
      sample(
        type: TransactionType.income,
        amount: 1880000,
        accountId: 'acc_bank',
        categoryId: 'cat_salary',
        occurredAt: timeAgo(5, 10, 0),
        note: '税后薪资到账',
      ),
      // 7 天前
      sample(
        type: TransactionType.expense,
        amount: 9900,
        accountId: 'acc_alipay',
        categoryId: 'cat_daily',
        occurredAt: timeAgo(7, 11, 20),
        note: '手机话费充值',
      ),
      sample(
        type: TransactionType.income,
        amount: 120000,
        accountId: 'acc_alipay',
        categoryId: 'cat_sideline',
        occurredAt: timeAgo(7, 16, 50),
        note: '设计外包尾款',
      ),
      // 10 天前
      sample(
        type: TransactionType.expense,
        amount: 26000,
        accountId: 'acc_credit',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(10, 19, 30),
        note: '朋友聚餐 A 账',
      ),
      sample(
        type: TransactionType.expense,
        amount: 3500,
        accountId: 'acc_wechat',
        categoryId: 'cat_medical',
        occurredAt: timeAgo(10, 16, 0),
        note: '药店常备感冒药',
      ),
      sample(
        type: TransactionType.expense,
        amount: 1200,
        accountId: 'acc_cash',
        categoryId: 'cat_dining',
        occurredAt: timeAgo(10, 8, 20),
        note: '街角豆浆油条',
      ),
    ];
  }
}