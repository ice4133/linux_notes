#include <QApplication>
#include <QWidget>
#include <QPushButton> // 1. 包含按钮头文件

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    
    QWidget window;
    window.resize(300, 200);
    window.setWindowTitle("Qt 6 环境测试");

    // 2. 创建一个按钮，并把 window 设置为它的“父亲”
    QPushButton *btn = new QPushButton("点我试试", &window);
    btn->setGeometry(100, 80, 100, 40); // 设置按钮在窗口里的位置和大小

    window.show();

    return app.exec();
}