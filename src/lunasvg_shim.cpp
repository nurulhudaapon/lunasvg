#include "lunasvg.h"

#include <cstddef>
#include <cstdint>

extern "C" bool lunasvg_svg_to_png(
    const char* svg_data,
    size_t svg_len,
    int width,
    int height,
    uint32_t background_color,
    lunasvg_write_func_t write_func,
    void* closure
) {
    auto document = lunasvg::Document::loadFromData(svg_data, svg_len);
    if (!document) {
        return false;
    }

    auto bitmap = document->renderToBitmap(width, height, background_color);
    if (bitmap.isNull()) {
        return false;
    }

    return bitmap.writeToPng(write_func, closure);
}
