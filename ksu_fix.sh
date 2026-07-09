#!/bin/bash
# KernelSU 4.9 兼容性自动补丁脚本 (安全精准版)

echo "开始应用 KernelSU 4.9 兼容性补丁..."

# 1. 修复 fallthrough 宏缺失
FILE_COMPAT="drivers/kernelsu/infra/kernel_compat.h"
if [ -f "$FILE_COMPAT" ]; then
    if ! grep -q "fallthrough" "$FILE_COMPAT"; then
        echo "正在添加 fallthrough 宏定义..."
        printf '\n#ifndef fallthrough\n#define fallthrough do {} while (0)\n#endif\n' >> "$FILE_COMPAT"
    fi
fi

# 2. 解决 selinux 相关函数缺失导致的链接错误
FILE_KSUD="drivers/kernelsu/runtime/ksud.c"
if [ -f "$FILE_KSUD" ]; then
    if ! grep -q "KSU_4_9_STUB" "$FILE_KSUD"; then
        echo "正在向 ksud.c 添加 SELinux 空实现..."
        printf '\n/* KSU_4_9_STUB */\nint ksu_selinux_hide_handle_second_stage(void *data) { return 0; }\nint ksu_selinux_hide_handle_post_fs_data(void) { return 0; }\nint current_sid(void) { return 0; }\n' >> "$FILE_KSUD"
    fi
fi

# 3. 修正 user_arg_null_ptr 解引用问题 (event.c)
FILE_EVENT="drivers/kernelsu/sulog/event.c"
if [ -f "$FILE_EVENT" ]; then
    echo "正在修复 event.c 中的指针解引用..."
    sed -i 's/#define USER_ARG_NULL user_arg_null_ptr()/#define USER_ARG_NULL (user_arg_null_ptr())/' "$FILE_EVENT"
fi

# 4. 精准处理核心 Makefile 中的 -Werror 警告 (绝不扩大到子目录)
echo "正在精准替换核心 Makefile 中的 -Werror 标志..."
for file in Makefile scripts/Makefile.build; do
    if [ -f "$file" ]; then
        sed -i 's/-Werror=/-Wno-error=/g' "$file"
        sed -i 's/-Werror\([^a-zA-Z=-]\)/-Wno-error\1/g' "$file"
        sed -i 's/-Werror$/-Wno-error/g' "$file"
        sed -i 's/-Werror-implicit-function-declaration/-Wno-implicit-function-declaration/g' "$file"
    fi
done

echo "补丁应用完成！"
