#!/bin/bash
# ====================================================
# [修复 2] KernelSU Core: 缺少宏、隐式声明与 SELinux API 兼容
# ====================================================

# --- 通用辅助函数 (以后每个脚本都会自带) ---
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_skip() { echo -e "\e[33m[SKIP]\e[0m $1 (已修复，跳过)"; }
log_err()  { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }
# -------------------------------------------

FILE_KSU_COMPAT="drivers/kernelsu/infra/kernel_compat.h"

if [ -f "$FILE_KSU_COMPAT" ]; then
    # 利用特殊注释来判断是否已经修复过
    if ! grep -q "SukiSU 4.9 Backport Fixes" "$FILE_KSU_COMPAT"; then
        log_info "正在修复 KernelSU 基础兼容性 (涵盖 8 个报错) ..."
        
        # 将所有补丁打包追加到 kernel_compat.h 文件的最末尾
        cat << 'EOF' >> "$FILE_KSU_COMPAT"

/* =======================================
 * SukiSU 4.9 Backport Fixes 
 * ======================================= */

/* 1. 修复 fallthrough 防呆宏缺失 */
#ifndef fallthrough
#define fallthrough do {} while (0)
#endif

/* 2. 修复带有和不带下划线的 API 差异 (马甲重定向) */
#ifndef strncpy_from_user_nofault
#define strncpy_from_user_nofault __strncpy_from_user_nofault
#endif

/* 3. 补充 selinux hide 相关函数的隐式声明 */
extern void ksu_selinux_hide_handle_post_fs_data(void);
extern void ksu_selinux_hide_handle_second_stage(void);

/* 4. 适配 4.9 的 SELinux SID 获取方式 (使用标准安全模块接口) */
#ifndef current_sid
#include <linux/security.h>
static inline u32 ksu_get_current_sid(void) {
    u32 sid = 0;
    /* 4.9 原生 API：安全地获取当前任务的 secid */
    security_task_getsecid(current, &sid);
    return sid;
}
#define current_sid() ksu_get_current_sid()
#endif
/* ======================================= */
EOF
    else
        log_skip "KernelSU 基础兼容性 (kernel_compat.h) 已经被修复"
    fi
else
    log_err "找不到 $FILE_KSU_COMPAT，请确认 SukiSU 路径是否在 drivers/kernelsu/ ！"
fi
