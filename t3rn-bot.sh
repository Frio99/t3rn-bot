#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/t3rn-bot.sh"

# 定义仓库地址和目录名称
REPO_URL="https://github.com/Frio99/t3rn-bot.git"
DIR_NAME="t3rn-bot"
PYTHON_FILE="keys_and_addresses.py"
DATA_BRIDGE_FILE="data_bridge.py"
BOT_FILE="bot.py"
VENV_DIR="t3rn-env"  # 虚拟环境目录

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 执行t3rn跨链脚本"
        echo "2. 退出"
        
        read -p "请输入选项 (1/2): " option
        case $option in
            1)
                execute_cross_chain_script
                ;;
            2)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择。"
                sleep 2
                ;;
        esac
    done
}

# 执行跨链脚本
function execute_cross_chain_script() {
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then 
        echo "请使用 sudo 运行此脚本"
        exit 1
    fi

    # 检查是否安装了 git
    if ! command -v git &> /dev/null; then
        echo "Git 未安装，请先安装 Git。"
        exit 1
    fi

    # 检查是否安装了 python3-pip 和 python3-venv
    if ! command -v pip3 &> /dev/null; then
        echo "pip 未安装，正在安装 python3-pip..."
        sudo apt update
        sudo apt install -y python3-pip
    fi

    # 检查并安装必要的包
    if ! command -v python3-venv &> /dev/null; then
        echo "正在安装 python3-venv..."
        sudo apt update
        sudo apt install -y python3-venv python3-pip
    fi

    # 拉取仓库
    if [ -d "$DIR_NAME" ]; then
        echo "目录 $DIR_NAME 已存在，拉取最新更新..."
        cd "$DIR_NAME" || exit
        git pull origin main
    else
        echo "正在克隆仓库 $REPO_URL..."
        git clone "$REPO_URL"
        cd "$DIR_NAME" || exit
    fi

    echo "已进入目录 $DIR_NAME"

    # 创建虚拟环境并激活
    echo "正在创建虚拟环境..."
    if [ -d "$VENV_DIR" ]; then
        echo "虚拟环境已存在，正在删除..."
        rm -rf "$VENV_DIR"
    fi
    
    python3 -m venv "$VENV_DIR"
    
    # 检查虚拟环境是否创建成功
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        echo "❌ 虚拟环境创建失败"
        echo "请检查 python3-venv 是否正确安装"
        exit 1
    fi
    
    echo "正在激活虚拟环境..."
    source "$VENV_DIR/bin/activate"
    
    # 检查虚拟环境是否成功激活
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "❌ 虚拟环境激活失败"
        echo "VIRTUAL_ENV 环境变量未设置"
        exit 1
    fi
    
    # 验证 Python 解释器
    if ! python3 -c "import sys; sys.exit(0 if sys.prefix == '$VIRTUAL_ENV' else 1)"; then
        echo "❌ Python 解释器不在虚拟环境中"
        echo "当前 Python 路径: $(which python3)"
        echo "预期路径: $VIRTUAL_ENV/bin/python3"
        exit 1
    fi
    
    echo "✅ 虚拟环境激活成功"
    echo "Python 路径: $(which python3)"

    # 升级 pip
    echo "正在升级 pip..."
    pip install --upgrade pip

    # 安装依赖
    echo "正在安装依赖 web3 和 colorama..."
    pip install web3 colorama

    # 提醒用户私钥安全
    echo "警告：请务必确保您的私钥安全！"
    echo "私钥应当保存在安全的位置，切勿公开分享或泄漏给他人。"
    echo "如果您的私钥被泄漏，可能导致您的资产丧失！"
    echo "请输入您的私钥，确保安全操作。"

    # 让用户输入私钥和标签
    echo "请输入您的私钥（多个私钥以空格分隔）："
    read -r private_keys_input

    echo "请输入您的标签（多个标签以空格分隔，与私钥顺序一致）："
    read -r labels_input

    # 检查输入是否一致
    IFS=' ' read -r -a private_keys <<< "$private_keys_input"
    IFS=' ' read -r -a labels <<< "$labels_input"

    if [ "${#private_keys[@]}" -ne "${#labels[@]}" ]; then
        echo "私钥和标签数量不一致，请重新运行脚本并确保它们匹配！"
        exit 1
    fi

    # 选择跨链方向
    echo "请选择要运行交易的链:"
    echo "1. Base -> OP Sepolia"
    echo "2. OP -> Base"
    read -p "输入选择 (1-2): " chain_choice

    # 验证输入
    if [[ ! "$chain_choice" =~ ^[1-2]$ ]]; then
        echo "无效的选择！请输入 1 或 2"
        exit 1
    fi

    # 输入跨链金额并验证
    while true; do
        read -p "请输入每次跨链的金额(ETH): " bridge_amount
        if [[ "$bridge_amount" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            break
        else
            echo "无效的金额！请输入有效的数字（例如：0.1 或 1.5）"
        fi
    done

    # 写入 keys_and_addresses.py 文件
    echo "正在写入 $PYTHON_FILE 文件..."
    cat > $PYTHON_FILE <<EOL
# 此文件由脚本生成

private_keys = [
$(printf "    '%s',\n" "${private_keys[@]}")
]

labels = [
$(printf "    '%s',\n" "${labels[@]}")
]

# 用户选择的链和金额
chain_choice = "${chain_choice}"
bridge_amount = ${bridge_amount}
EOL

    echo "$PYTHON_FILE 文件已生成。"

    # 提醒用户私钥安全
    echo "脚本执行完成！所有依赖已安装，私钥和标签已保存到 $PYTHON_FILE 中。"
    echo "请务必妥善保管此文件，避免泄露您的私钥和标签信息！"

    # 获取额外的用户输入："Base - OP Sepolia" 和 "OP - Base"
    echo "请输入 'Base - OP Sepolia' 的值："
    read -r base_op_sepolia_value

    echo "请输入 'OP - Base' 的值："
    read -r op_base_value

    # 写入 data_bridge.py 文件
    echo "正在写入 $DATA_BRIDGE_FILE 文件..."
    cat > $DATA_BRIDGE_FILE <<EOL
# 此文件由脚本生成

data_bridge = {
    # Data bridge Base
    "Base - OP Sepolia": "$base_op_sepolia_value",

    # Data bridge OP Sepolia
    "OP - Base": "$op_base_value",
}
EOL

    echo "$DATA_BRIDGE_FILE 文件已生成。"

    # 提醒用户运行 bot.py
    echo "配置完成，正在通过 screen 运行 bot.py..."

    # 使用 screen 后台运行 bot.py
    echo "正在启动 screen 会话..."
    
    # 显示当前目录和文件路径
    echo "当前目录: $(pwd)"
    echo "Python文件: $BOT_FILE"
    echo "虚拟环境: $VENV_DIR"
    
    # 使用完整路径并重定向错误输出
    screen -dmS t3rn-bot bash -c "cd $(pwd) && source $VENV_DIR/bin/activate && python3 $BOT_FILE" 2>&1
    
    # 检查 screen 是否成功启动
    if screen -ls | grep -q "t3rn-bot"; then
        echo "screen 会话已成功启动"
        echo "您可以使用 'screen -r t3rn-bot' 查看运行日志"
        echo -e "\n当前运行中的 screen 会话:"
        screen -ls
        exit 0  # 直接退出脚本
    else
        echo "screen 会话启动失败"
        echo "错误信息:"
        screen -ls
        exit 1  # 出错时退出
    fi
}

# 启动主菜单（只执行一次）
main_menu
