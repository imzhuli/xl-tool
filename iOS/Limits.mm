#import <Foundation/Foundation.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include "./kern_memorystatus.h"
#include "./Limits.hpp"

int SetHighWaterMark(int32_t pid, int limit) {
    int cmd = MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK;
    int result = memorystatus_control(cmd, pid, limit, 0, 0);
    if (result) {
        fprintf(stderr, "failed to setHighWaterMark of pid %d to %dMB: %d\n", pid, limit, errno);
    }
    return result;
}

int GetHightWaterMark(int32_t pid) {
    int size = memorystatus_control(MEMORYSTATUS_CMD_GET_PRIORITY_LIST, 0, 0, NULL, 0);
    if (size < 0) {
        fprintf(stderr, "failed to get priority list size: %d\n", errno);
        return -1;
    }

    memorystatus_priority_entry_t *list = (memorystatus_priority_entry_t *)malloc(size);
    if (!list) {
        fprintf(stderr, "failed to allocate memory of size %d: %d\n", size, errno);
        return -1;
    }

    size = memorystatus_control(MEMORYSTATUS_CMD_GET_PRIORITY_LIST, 0, 0, list, size);
    int count = size / sizeof(memorystatus_priority_entry_t);
    for (int i = 0; i < count; ++i) {
        memorystatus_priority_entry_t *entry = list + i;
        if (entry->pid == pid) return entry->limit;
    }
    return -1;
}