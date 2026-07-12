#!/bin/bash
# ====================================================
# [修复 3] 链接器报错：修复缺失的空函数与数据结构对齐 (1字节与4字节冲突)
# 报错类型: undefined reference / relocation truncated
# ====================================================

# --- 通用辅助函数 ---
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_skip() { echo -e "\e[33m[SKIP]\e[0m $1 (已修复，跳过)"; }
log_err()  { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }
# -------------------------------------------

FILE_KSU_COMPAT="drivers/kernelsu/infra/kernel_compat.h"

log_info "开始处理链接器阶段报错..."

# 1. 修复 Undefined reference (将之前的 extern 声明改写为空函数实现)
if grep -q "extern void ksu_selinux_hide_handle_post_fs_data(void);" "$FILE_KSU_COMPAT"; then
    log_info "正在注入空函数以修复 selinux hide 相关链接错误..."
    sed -i 's/extern void ksu_selinux_hide_handle_post_fs_data(void);/static inline void ksu_selinux_hide_handle_post_fs_data(void) {}/g' "$FILE_KSU_COMPAT"
    sed -i 's/extern void ksu_selinux_hide_handle_second_stage(void);/static inline void ksu_selinux_hide_handle_second_stage(void) {}/g' "$FILE_KSU_COMPAT"
else
    log_skip "selinux hide 空函数已注入"
fi

# 2. 修复对齐异常 (将 1 字节的 bool 统一升级为 4 字节的 int，解决 LDST32 重定位报错)
# 我们在 fs/、drivers/kernelsu/ 和 include/ 三个可能涉事的目录里全局搜索并替换
CHECK_VAR=$(grep -r "bool ksu_su_compat_enabled" drivers/kernelsu/ 2>/dev/null)
if [ -n "$CHECK_VAR" ]; then
    log_info "正在全局统一 ksu_su_compat_enabled 的数据类型 (bool -> int)..."
    
    # 找出所有包含该变量定义或声明的文件并修改
    find drivers/kernelsu/ fs/ include/ -type f \( -name "*.c" -o -name "*.h" \) 2>/dev/null | xargs grep -l "bool ksu_su_compat_enabled" | while read -r target_file; do
        sed -i 's/\bbool ksu_su_compat_enabled\b/int ksu_su_compat_enabled/g' "$target_file"
        log_info "  已修补 -> $target_file"
    done
else
    log_skip "ksu_su_compat_enabled 类型已统一"
fi

log_info "第 3 关修复完成，请重新 make！"
