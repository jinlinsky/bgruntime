include theos/makefiles/common.mk

TWEAK_NAME = bgruntime
bgruntime_FILES = Tweak.xm Socket.mm File.mm
bgruntime_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
