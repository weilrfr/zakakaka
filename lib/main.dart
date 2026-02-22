import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Нужно для корректного выхода из приложения

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Модели
// ─────────────────────────────────────────────────────────────

const Map<String, List<String>> categorySizes = {
  'Одежда': ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  'Обувь': ['36', '37', '38', '39', '40', '41', '42', '43', '44'],
  'Аксессуары': ['One Size'],
};

class Product {
  final int id;
  final String name;
  final String price;
  final String imageUrl;
  final String description;
  final String category;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.category,
  });

  List<String> get sizes => categorySizes[category] ?? ['One Size'];

  int get priceValue =>
      int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

class CartItem {
  final Product product;
  final String size;
  int quantity;

  CartItem({required this.product, required this.size, this.quantity = 1});
}

// ─────────────────────────────────────────────────────────────
// Менеджер корзины (singleton + ChangeNotifier)
// ─────────────────────────────────────────────────────────────

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.product.priceValue * item.quantity);

  void addItem(Product product, String size) {
    final idx = _items.indexWhere(
      (i) => i.product.id == product.id && i.size == size,
    );
    if (idx != -1) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(product: product, size: size));
    }
    notifyListeners();
  }

  void increment(CartItem item) {
    item.quantity++;
    notifyListeners();
  }

  void decrement(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────
// Менеджер избранного (singleton + ChangeNotifier)
// ─────────────────────────────────────────────────────────────

class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager instance = FavoritesManager._internal();
  FavoritesManager._internal();

  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  int get count => _items.length;

  bool isFavorite(Product product) =>
      _items.any((p) => p.id == product.id);

  void toggle(Product product) {
    if (isFavorite(product)) {
      _items.removeWhere((p) => p.id == product.id);
    } else {
      _items.add(product);
    }
    notifyListeners();
  }

  void remove(Product product) {
    _items.removeWhere((p) => p.id == product.id);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────
// Модель заказа и менеджер заказов
// ─────────────────────────────────────────────────────────────

enum OrderStatus { processing, shipped, delivered }

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.processing: return 'В обработке';
      case OrderStatus.shipped:    return 'В пути';
      case OrderStatus.delivered:  return 'Доставлен';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.processing: return Colors.orange;
      case OrderStatus.shipped:    return Colors.blue;
      case OrderStatus.delivered:  return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.processing: return Icons.inventory_2_outlined;
      case OrderStatus.shipped:    return Icons.local_shipping_outlined;
      case OrderStatus.delivered:  return Icons.check_circle_outline;
    }
  }
}

class OrderProduct {
  final Product product;
  final String size;
  final int quantity;

  const OrderProduct({
    required this.product,
    required this.size,
    required this.quantity,
  });
}

class Order {
  final String id;
  final DateTime date;
  final List<OrderProduct> items;
  final int totalPrice;
  OrderStatus status;
  DateTime? shippedAt;
  DateTime? deliveredAt;

  Order({
    required this.id,
    required this.date,
    required this.items,
    required this.totalPrice,
    this.status = OrderStatus.processing,
  });
}

// Интервалы смены статусов
const _kProcessingDuration = Duration(seconds: 10);
const _kShippedDuration    = Duration(seconds: 10);

class OrdersManager extends ChangeNotifier {
  static final OrdersManager instance = OrdersManager._internal();
  OrdersManager._internal();

  final List<Order> _orders = [];
  final Map<String, List<Timer>> _timers = {};

  List<Order> get orders => List.unmodifiable(_orders.reversed.toList());
  int get count => _orders.length;

  void addOrder(List<CartItem> cartItems, int totalPrice) {
    final order = Order(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      items: cartItems
          .map((i) => OrderProduct(
                product: i.product,
                size: i.size,
                quantity: i.quantity,
              ))
          .toList(),
      totalPrice: totalPrice,
    );
    _orders.add(order);
    notifyListeners();
    _scheduleStatusUpdates(order);
  }

  void _scheduleStatusUpdates(Order order) {
    final t1 = Timer(_kProcessingDuration, () {
      order.status = OrderStatus.shipped;
      order.shippedAt = DateTime.now();
      notifyListeners();
    });

    final t2 = Timer(_kProcessingDuration + _kShippedDuration, () {
      order.status = OrderStatus.delivered;
      order.deliveredAt = DateTime.now();
      notifyListeners();
    });

    _timers[order.id] = [t1, t2];
  }
}

// ─────────────────────────────────────────────────────────────
// Демо-товары
// ─────────────────────────────────────────────────────────────

final List<Product> demoProducts = [
  Product(
    id: 1,
    name: 'Товар #1',
    price: '1200 tenge',
    imageUrl: 'https://picsum.photos/400/600?random=1',
    description:
        'Стильный товар высокого качества. Идеально подойдёт для повседневного использования.',
    category: 'Одежда',
  ),
  Product(
    id: 2,
    name: 'Товар #2',
    price: '2400 tenge',
    imageUrl: 'https://picsum.photos/400/600?random=2',
    description:
        'Премиальный товар из новой коллекции. Современный дизайн и отличное качество.',
    category: 'Обувь',
  ),
  Product(
    id: 3,
    name: 'Товар #3',
    price: '3600 tenge',
    imageUrl: 'https://picsum.photos/400/600?random=3',
    description:
        'Эксклюзивный товар ограниченной серии. Прекрасный выбор для особых случаев.',
    category: 'Аксессуары',
  ),
  Product(
    id: 4,
    name: 'Товар #4',
    price: '4800 tenge',
    imageUrl: 'https://picsum.photos/400/600?random=4',
    description: 'Трендовый товар сезона. Сочетает в себе комфорт и стиль.',
    category: 'Одежда',
  ),
];

// ─────────────────────────────────────────────────────────────
// Главный экран (Обертка с нижним меню и вложенной навигацией)
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Главный экран (Обертка с ПАРЯЩИМ нижним меню)
// ─────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Главная
    GlobalKey<NavigatorState>(), // Избранное
    GlobalKey<NavigatorState>(), // Корзина
    GlobalKey<NavigatorState>(), // Заказы
    GlobalKey<NavigatorState>(), // Профиль
  ];

  Widget _buildTabNavigator(int index, Widget page) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final currentNavigator = _navigatorKeys[_currentIndex].currentState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // Используем extendBody, чтобы контент мог просвечивать под меню, если оно прозрачное
        extendBody: true, 
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const HomePage()),
            _buildTabNavigator(1, const FavoritesPage()),
            _buildTabNavigator(2, const CartPage()),
            _buildTabNavigator(3, const OrdersPage()),
            _buildTabNavigator(4, const ProfilePage()),
          ],
        ),
        // Наше кастомное "парящее" меню
        bottomNavigationBar: _buildFloatingBar(),
      ),
    );
  }

  Widget _buildFloatingBar() {
    return Container(
      // Отступы вокруг меню, чтобы оно "парило"
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // Слегка прозрачный фон
        borderRadius: BorderRadius.circular(35), // Полностью закругленные края
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home_outlined, Icons.home, "Главная", 0),
          _buildNavItem(Icons.favorite_border, Icons.favorite, "Избранное", 1, isFavorite: true),
          _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, "Корзина", 2, isCart: true),
          _buildNavItem(Icons.receipt_long_outlined, Icons.receipt_long, "Заказы", 3, isOrders: true),
          _buildNavItem(Icons.person_outline, Icons.person, "Профиль", 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, {bool isCart = false, bool isFavorite = false, bool isOrders = false}) {
    final bool isSelected = _currentIndex == index;
    final Color color = isSelected ? Colors.blue : Colors.grey[600]!;

    return GestureDetector(
      onTap: () {
        if (index == _currentIndex) {
          _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
        } else {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка с возможным бейджем
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isSelected ? activeIcon : icon, color: color, size: 26),
                if (isCart) _buildBadge(CartManager.instance, (m) => m.totalCount),
                if (isFavorite) _buildBadge(FavoritesManager.instance, (m) => m.count),
                if (isOrders) _buildBadge(OrdersManager.instance, (m) => m.count),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный виджет для цифр (бейджиков) над иконками
  Widget _buildBadge(Listenable manager, int Function(dynamic) countGetter) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final count = countGetter(manager);
        if (count == 0) return const SizedBox.shrink();
        return Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Главная страница (Список товаров)
// ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> _categories = ['Все', 'Одежда', 'Обувь', 'Аксессуары'];
  String _selectedCategory = 'Все';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    List<Product> result = demoProducts;

    if (_selectedCategory != 'Все') {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(_searchQuery) ||
            p.description.toLowerCase().contains(_searchQuery) ||
            p.category.toLowerCase().contains(_searchQuery) ||
            p.price.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        toolbarHeight: 20,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Найди свой стиль",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Поиск товаров...",
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              "Категории",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _buildCategoryChip(
                    category,
                    category == _selectedCategory,
                    onTap: () =>
                        setState(() => _selectedCategory = category),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off,
                          size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Ничего не найдено по запросу «$_searchQuery»'
                            : 'Товаров в этой категории нет',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Text('Сбросить поиск'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    _buildProductCard(context, products[index]),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      // Теперь этот push сработает внутри вложенного Navigator вкладки "Главная"
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(product.imageUrl,
                    fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    product.price,
                    style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Детальная страница товара
// ─────────────────────────────────────────────────────────────

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _selectedSizeIndex = 0;
  final cart = CartManager.instance;
  final favorites = FavoritesManager.instance;

  @override
  Widget build(BuildContext context) {
    final sizes = widget.product.sizes;
    final bool isNumericSize = widget.product.category == 'Обувь';
    final double chipWidth = isNumericSize ? 60.0 : 52.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8),
                  ],
                ),
                child:
                    const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8),
                  ],
                ),
                child: ListenableBuilder(
                  listenable: favorites,
                  builder: (context, _) {
                    final isFav = favorites.isFavorite(widget.product);
                    return IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.black,
                      ),
                      onPressed: () {
                        favorites.toggle(widget.product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav
                                  ? '${widget.product.name} удалён из избранного'
                                  : '${widget.product.name} добавлен в избранное',
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background:
                  Image.network(widget.product.imageUrl, fit: BoxFit.cover),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.product.category,
                      style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(widget.product.price,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700])),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text("Описание",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.product.description,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          height: 1.5)),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      const Text("Размер",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Text(
                        "— ${sizes[_selectedSizeIndex]}",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sizes.length,
                      itemBuilder: (context, index) => _buildSizeChip(
                        sizes[index],
                        index == _selectedSizeIndex,
                        chipWidth,
                        onTap: () =>
                            setState(() => _selectedSizeIndex = index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final selectedSize = sizes[_selectedSizeIndex];
                        cart.addItem(widget.product, selectedSize);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${widget.product.name} добавлен в корзину',
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            action: SnackBarAction(
                              label: 'Открыть',
                              textColor: Colors.white,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CartPage()),
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "Добавить в корзину",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeChip(String size, bool isSelected, double width,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        width: width,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? Colors.black : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(size,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Страница корзины
// ─────────────────────────────────────────────────────────────

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartManager.instance;
    // Проверяем, можем ли мы вернуться назад на предыдущую страницу. 
    // Если мы зашли сюда из меню внизу — стрелки назад не будет. Если из карточки товара — будет.
    final canPop = Navigator.canPop(context);

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final items = cart.items;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: const Text(
              'Корзина',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => _showClearDialog(context, cart),
                  child: const Text('Очистить',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          body: items.isEmpty
              ? _buildEmptyCart(context, canPop)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildCartItem(context, items[index], cart),
                      ),
                    ),
                    _buildCheckoutBar(context, cart),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyCart(BuildContext context, bool canPop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 90, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Корзина пуста',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте товары, чтобы продолжить',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          if (canPop)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Назад к покупкам',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItem(
      BuildContext context, CartItem item, CartManager cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.product.imageUrl,
                width: 80,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Размер: ${item.size}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(item.product.price,
                      style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () => cart.remove(item),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _CounterButton(
                        icon: Icons.remove,
                        onTap: () => cart.decrement(item),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      _CounterButton(
                        icon: Icons.add,
                        onTap: () => cart.increment(item),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _buildCheckoutBar(BuildContext context, CartManager cart) {
  return Container(
    // Увеличиваем нижний внутренний отступ (был 28, стал 100)
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), 
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Товаров: ${cart.totalCount}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text(
              'Итого: ${cart.totalPrice} tenge',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => _showOrderDialog(context, cart),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Оформить заказ',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ),
  );
}

  void _showClearDialog(BuildContext context, CartManager cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Очистить корзину?'),
        content: const Text('Все товары будут удалены из корзины.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(context);
            },
            child: const Text('Очистить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showOrderDialog(BuildContext context, CartManager cart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Заказ оформлен!'),
          ],
        ),
        content: Text(
          'Спасибо за покупку! Сумма заказа: ${cart.totalPrice} tenge.\n\nСтатус заказа можно отследить в разделе «Заказы».',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              OrdersManager.instance.addOrder(
                List.from(cart.items),
                cart.totalPrice,
              );
              cart.clear();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Отлично!'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Страница избранного
// ─────────────────────────────────────────────────────────────

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesManager.instance;
    final canPop = Navigator.canPop(context);

    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        final items = favorites.items;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: const Text(
              'Избранное',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => _showClearDialog(context, favorites),
                  child: const Text('Очистить',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          body: items.isEmpty
              ? _buildEmpty(context, canPop)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildFavoriteCard(context, items[index], favorites),
                ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool canPop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Нет избранных товаров',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите ♡ на странице товара, чтобы добавить',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (canPop)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Назад к покупкам',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(
      BuildContext context, Product product, FavoritesManager favorites) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: Image.network(product.imageUrl,
                        fit: BoxFit.cover, width: double.infinity),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => favorites.remove(product),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.red, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.price,
                        style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () {
                          CartManager.instance
                              .addItem(product, product.sizes.first);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${product.name} добавлен в корзину'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_shopping_cart,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, FavoritesManager favorites) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Очистить избранное?'),
        content:
            const Text('Все товары будут удалены из избранного.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              for (final p in List.from(favorites.items)) {
                favorites.remove(p);
              }
              Navigator.pop(context);
            },
            child: const Text('Очистить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Страницы-заглушки для новых разделов меню
// ─────────────────────────────────────────────────────────────

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OrdersManager.instance,
      builder: (context, _) {
        final orders = OrdersManager.instance.orders;
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Мои заказы',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: orders.isEmpty ? _buildEmpty() : _buildList(context, orders),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('У вас пока нет заказов',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Оформите первый заказ из корзины',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Order> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final dateStr = _formatDate(order.date);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.id,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  _StatusBadge(order: order),
                ],
              ),
              const SizedBox(height: 8),
              Text(dateStr,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  ...order.items.take(3).map((item) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 52,
                        height: 62,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: NetworkImage(item.product.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )),
                  if (order.items.length > 3)
                    Container(
                      width: 52,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('+${order.items.length - 3}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${order.items.length} ${_itemWord(order.items.length)}',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13)),
                  Text('${order.totalPrice} tenge',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _itemWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'товар';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) return 'товара';
    return 'товаров';
  }
}

// ─────────────────────────────────────────────────────────────
// Виджет статуса — обновляется реактивно
// ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final Order order;
  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OrdersManager.instance,
      builder: (_, __) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: order.status.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(order.status.icon,
                size: 13, color: order.status.color),
            const SizedBox(width: 4),
            Text(
              order.status.label,
              style: TextStyle(
                  color: order.status.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Детальная страница заказа
// ─────────────────────────────────────────────────────────────

class OrderDetailPage extends StatelessWidget {
  final Order order;
  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OrdersManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(order.id,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusTracker(),
              const SizedBox(height: 16),
              _buildProductsList(),
              const SizedBox(height: 16),
              _buildTotal(),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusTracker() {
    final steps = [
      OrderStatus.processing,
      OrderStatus.shipped,
      OrderStatus.delivered,
    ];
    final currentIdx = steps.indexOf(order.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Статус заказа',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Линия между шагами
                final lineIdx = i ~/ 2;
                final isDone = currentIdx > lineIdx;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDone ? Colors.black : Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final step = steps[stepIdx];
              final isDone = currentIdx >= stepIdx;
              return Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDone ? step.color : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.icon,
                      size: 22,
                      color: isDone ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isDone
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isDone ? Colors.black : Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[100]),
          const SizedBox(height: 8),
          _buildDateRow(
              Icons.access_time, 'Оформлен', order.date),
          if (order.shippedAt != null)
            _buildDateRow(
                Icons.local_shipping_outlined, 'Передан в доставку', order.shippedAt!),
          if (order.deliveredAt != null)
            _buildDateRow(
                Icons.check_circle_outline, 'Доставлен', order.deliveredAt!),
        ],
      ),
    );
  }

  Widget _buildDateRow(IconData icon, String label, DateTime dt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Товары',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          ...order.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (i > 0)
                  Divider(
                      height: 1,
                      color: Colors.grey[100],
                      indent: 16,
                      endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.product.imageUrl,
                          width: 72,
                          height: 82,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Размер: ${item.size}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Кол-во: ${item.quantity}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Text(
                        '${item.product.priceValue * item.quantity} tenge',
                        style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Итого',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${order.totalPrice} tenge',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue[700])),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Профиль', style: TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.black12,
              child: Icon(Icons.person, size: 50, color: Colors.black),
            ),
            const SizedBox(height: 16),
            const Text('Привет, покупатель!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('user@example.com',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Кнопка счётчика (+/-)
// ─────────────────────────────────────────────────────────────

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}