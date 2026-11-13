// Stop an idle stream even if Island is killed without closing it explicitly.
// This file belongs to Island; the vendored adapter sources remain unchanged.
#import <Foundation/Foundation.h>
#include <unistd.h>

static dispatch_source_t parentWatch;

__attribute__((constructor)) static void watchParentLifetime(void) {
    pid_t originalParent = getppid();
    if (originalParent <= 1) return;
    parentWatch = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                         dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(parentWatch, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                              NSEC_PER_SEC, NSEC_PER_SEC / 4);
    dispatch_source_set_event_handler(parentWatch, ^{
        if (getppid() != originalParent) _exit(EXIT_SUCCESS);
    });
    dispatch_resume(parentWatch);
}
