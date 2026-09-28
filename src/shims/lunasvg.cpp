#include "lunasvg_c.h"
#include "lunasvg.h"

#include <cstring>
#include <memory>
#include <string>
#include <utility>
#include <vector>

struct lunasvg_document {
    std::unique_ptr<lunasvg::Document> inner;
};

struct lunasvg_bitmap {
    lunasvg::Bitmap inner;
};

struct lunasvg_element {
    lunasvg::Element inner;
};

static lunasvg_matrix_t to_c(const lunasvg::Matrix& m) {
    return {m.a, m.b, m.c, m.d, m.e, m.f};
}

static lunasvg::Matrix from_c(const lunasvg_matrix_t& m) {
    return lunasvg::Matrix(m.a, m.b, m.c, m.d, m.e, m.f);
}

static lunasvg_box_t to_c(const lunasvg::Box& b) {
    return {b.x, b.y, b.w, b.h};
}

static lunasvg::Box from_c(const lunasvg_box_t& b) {
    return lunasvg::Box(b.x, b.y, b.w, b.h);
}

static lunasvg_bitmap_t* wrap_bitmap(lunasvg::Bitmap bitmap) {
    if (bitmap.isNull()) {
        return nullptr;
    }
    auto* out = new (std::nothrow) lunasvg_bitmap_t{std::move(bitmap)};
    return out;
}

static lunasvg_element_t* wrap_element(lunasvg::Element element) {
    if (!element) {
        return nullptr;
    }
    auto* out = new (std::nothrow) lunasvg_element_t{element};
    return out;
}

extern "C" int lunasvg_c_version(void) {
    return lunasvg_version();
}

extern "C" const char* lunasvg_c_version_string(void) {
    return lunasvg_version_string();
}

extern "C" bool lunasvg_c_add_font_face_from_file(const char* family, bool bold, bool italic, const char* filename) {
    return lunasvg_add_font_face_from_file(family, bold, italic, filename);
}

extern "C" bool lunasvg_c_add_font_face_from_data(
    const char* family,
    bool bold,
    bool italic,
    const void* data,
    size_t length,
    lunasvg_destroy_func_t destroy_func,
    void* closure
) {
    return lunasvg_add_font_face_from_data(family, bold, italic, data, length, destroy_func, closure);
}

extern "C" lunasvg_document_t* lunasvg_document_load_from_file(const char* filename) {
    auto document = lunasvg::Document::loadFromFile(filename);
    if (!document) {
        return nullptr;
    }
    auto* out = new (std::nothrow) lunasvg_document_t{std::move(document)};
    return out;
}

extern "C" lunasvg_document_t* lunasvg_document_load_from_data(const char* data, size_t length) {
    auto document = lunasvg::Document::loadFromData(data, length);
    if (!document) {
        return nullptr;
    }
    auto* out = new (std::nothrow) lunasvg_document_t{std::move(document)};
    return out;
}

extern "C" void lunasvg_document_destroy(lunasvg_document_t* document) {
    delete document;
}

extern "C" float lunasvg_document_width(const lunasvg_document_t* document) {
    return document->inner->width();
}

extern "C" float lunasvg_document_height(const lunasvg_document_t* document) {
    return document->inner->height();
}

extern "C" lunasvg_box_t lunasvg_document_bounding_box(const lunasvg_document_t* document) {
    return to_c(document->inner->boundingBox());
}

extern "C" void lunasvg_document_apply_stylesheet(lunasvg_document_t* document, const char* css, size_t length) {
    document->inner->applyStyleSheet(std::string(css, length));
}

extern "C" void lunasvg_document_update_layout(lunasvg_document_t* document) {
    document->inner->updateLayout();
}

extern "C" void lunasvg_document_force_layout(lunasvg_document_t* document) {
    document->inner->forceLayout();
}

extern "C" void lunasvg_document_render(
    const lunasvg_document_t* document,
    lunasvg_bitmap_t* bitmap,
    const lunasvg_matrix_t* matrix
) {
    if (matrix) {
        document->inner->render(bitmap->inner, from_c(*matrix));
    } else {
        document->inner->render(bitmap->inner);
    }
}

extern "C" lunasvg_bitmap_t* lunasvg_document_render_to_bitmap(
    const lunasvg_document_t* document,
    int width,
    int height,
    uint32_t background_color
) {
    return wrap_bitmap(document->inner->renderToBitmap(width, height, background_color));
}

extern "C" lunasvg_element_t* lunasvg_document_element_from_point(const lunasvg_document_t* document, float x, float y) {
    return wrap_element(document->inner->elementFromPoint(x, y));
}

extern "C" lunasvg_element_t* lunasvg_document_get_element_by_id(
    const lunasvg_document_t* document,
    const char* id,
    size_t id_len
) {
    return wrap_element(document->inner->getElementById(std::string(id, id_len)));
}

extern "C" lunasvg_element_t* lunasvg_document_document_element(const lunasvg_document_t* document) {
    return wrap_element(document->inner->documentElement());
}

extern "C" lunasvg_element_t** lunasvg_document_query_selector_all(
    const lunasvg_document_t* document,
    const char* selectors,
    size_t selectors_len,
    size_t* out_count
) {
    auto elements = document->inner->querySelectorAll(std::string(selectors, selectors_len));
    auto** out = new (std::nothrow) lunasvg_element_t*[elements.size()];
    if (!out) {
        *out_count = 0;
        return nullptr;
    }
    for (size_t i = 0; i < elements.size(); ++i) {
        out[i] = wrap_element(elements[i]);
        if (!out[i]) {
            for (size_t j = 0; j < i; ++j) {
                delete out[j];
            }
            delete[] out;
            *out_count = 0;
            return nullptr;
        }
    }
    *out_count = elements.size();
    return out;
}

extern "C" void lunasvg_element_list_destroy(lunasvg_element_t** elements) {
    if (!elements) {
        return;
    }
    // Caller passes the pointer returned by query_selector_all; we don't know count here.
    // Zig frees each element then calls this with the array pointer only after freeing items.
    delete[] elements;
}

extern "C" lunasvg_bitmap_t* lunasvg_bitmap_create(int width, int height) {
    return wrap_bitmap(lunasvg::Bitmap(width, height));
}

extern "C" lunasvg_bitmap_t* lunasvg_bitmap_create_for_data(uint8_t* data, int width, int height, int stride) {
    return wrap_bitmap(lunasvg::Bitmap(data, width, height, stride));
}

extern "C" void lunasvg_bitmap_destroy(lunasvg_bitmap_t* bitmap) {
    delete bitmap;
}

extern "C" uint8_t* lunasvg_bitmap_data(const lunasvg_bitmap_t* bitmap) {
    return bitmap->inner.data();
}

extern "C" int lunasvg_bitmap_width(const lunasvg_bitmap_t* bitmap) {
    return bitmap->inner.width();
}

extern "C" int lunasvg_bitmap_height(const lunasvg_bitmap_t* bitmap) {
    return bitmap->inner.height();
}

extern "C" int lunasvg_bitmap_stride(const lunasvg_bitmap_t* bitmap) {
    return bitmap->inner.stride();
}

extern "C" bool lunasvg_bitmap_is_null(const lunasvg_bitmap_t* bitmap) {
    return bitmap == nullptr || bitmap->inner.isNull();
}

extern "C" void lunasvg_bitmap_clear(lunasvg_bitmap_t* bitmap, uint32_t color) {
    bitmap->inner.clear(color);
}

extern "C" void lunasvg_bitmap_convert_to_rgba(lunasvg_bitmap_t* bitmap) {
    bitmap->inner.convertToRGBA();
}

extern "C" bool lunasvg_bitmap_write_to_png_file(const lunasvg_bitmap_t* bitmap, const char* filename) {
    return bitmap->inner.writeToPng(filename);
}

extern "C" bool lunasvg_bitmap_write_to_png(
    const lunasvg_bitmap_t* bitmap,
    lunasvg_write_func_t write_func,
    void* closure
) {
    return bitmap->inner.writeToPng(write_func, closure);
}

extern "C" bool lunasvg_element_is_null(const lunasvg_element_t* element) {
    return element == nullptr || !element->inner;
}

extern "C" bool lunasvg_element_has_attribute(const lunasvg_element_t* element, const char* name, size_t name_len) {
    return element->inner.hasAttribute(std::string(name, name_len));
}

extern "C" const char* lunasvg_element_get_attribute(
    const lunasvg_element_t* element,
    const char* name,
    size_t name_len,
    size_t* out_len
) {
    const auto& value = element->inner.getAttribute(std::string(name, name_len));
    *out_len = value.size();
    return value.c_str();
}

extern "C" void lunasvg_element_set_attribute(
    lunasvg_element_t* element,
    const char* name,
    size_t name_len,
    const char* value,
    size_t value_len
) {
    element->inner.setAttribute(std::string(name, name_len), std::string(value, value_len));
}

extern "C" void lunasvg_element_render(
    const lunasvg_element_t* element,
    lunasvg_bitmap_t* bitmap,
    const lunasvg_matrix_t* matrix
) {
    if (matrix) {
        element->inner.render(bitmap->inner, from_c(*matrix));
    } else {
        element->inner.render(bitmap->inner);
    }
}

extern "C" lunasvg_bitmap_t* lunasvg_element_render_to_bitmap(
    const lunasvg_element_t* element,
    int width,
    int height,
    uint32_t background_color
) {
    return wrap_bitmap(element->inner.renderToBitmap(width, height, background_color));
}

extern "C" lunasvg_matrix_t lunasvg_element_get_local_matrix(const lunasvg_element_t* element) {
    return to_c(element->inner.getLocalMatrix());
}

extern "C" lunasvg_matrix_t lunasvg_element_get_global_matrix(const lunasvg_element_t* element) {
    return to_c(element->inner.getGlobalMatrix());
}

extern "C" lunasvg_box_t lunasvg_element_get_local_bounding_box(const lunasvg_element_t* element) {
    return to_c(element->inner.getLocalBoundingBox());
}

extern "C" lunasvg_box_t lunasvg_element_get_global_bounding_box(const lunasvg_element_t* element) {
    return to_c(element->inner.getGlobalBoundingBox());
}

extern "C" lunasvg_box_t lunasvg_element_get_bounding_box(const lunasvg_element_t* element) {
    return to_c(element->inner.getBoundingBox());
}

extern "C" lunasvg_matrix_t lunasvg_matrix_identity(void) {
    return to_c(lunasvg::Matrix());
}

extern "C" lunasvg_matrix_t lunasvg_matrix_translated(float tx, float ty) {
    return to_c(lunasvg::Matrix::translated(tx, ty));
}

extern "C" lunasvg_matrix_t lunasvg_matrix_scaled(float sx, float sy) {
    return to_c(lunasvg::Matrix::scaled(sx, sy));
}

extern "C" lunasvg_matrix_t lunasvg_matrix_rotated(float angle, float cx, float cy) {
    return to_c(lunasvg::Matrix::rotated(angle, cx, cy));
}

extern "C" lunasvg_matrix_t lunasvg_matrix_sheared(float shx, float shy) {
    return to_c(lunasvg::Matrix::sheared(shx, shy));
}

extern "C" lunasvg_matrix_t lunasvg_matrix_multiply(lunasvg_matrix_t lhs, lunasvg_matrix_t rhs) {
    return to_c(from_c(lhs) * from_c(rhs));
}

extern "C" lunasvg_matrix_t lunasvg_matrix_translate(lunasvg_matrix_t matrix, float tx, float ty) {
    auto m = from_c(matrix);
    m.translate(tx, ty);
    return to_c(m);
}

extern "C" lunasvg_matrix_t lunasvg_matrix_scale(lunasvg_matrix_t matrix, float sx, float sy) {
    auto m = from_c(matrix);
    m.scale(sx, sy);
    return to_c(m);
}

extern "C" lunasvg_matrix_t lunasvg_matrix_rotate(lunasvg_matrix_t matrix, float angle, float cx, float cy) {
    auto m = from_c(matrix);
    m.rotate(angle, cx, cy);
    return to_c(m);
}

extern "C" lunasvg_matrix_t lunasvg_matrix_shear(lunasvg_matrix_t matrix, float shx, float shy) {
    auto m = from_c(matrix);
    m.shear(shx, shy);
    return to_c(m);
}

extern "C" lunasvg_matrix_t lunasvg_matrix_invert(lunasvg_matrix_t matrix) {
    auto m = from_c(matrix);
    m.invert();
    return to_c(m);
}

extern "C" lunasvg_matrix_t lunasvg_matrix_inverse(lunasvg_matrix_t matrix) {
    return to_c(from_c(matrix).inverse());
}

extern "C" lunasvg_box_t lunasvg_box_transformed(lunasvg_box_t box, lunasvg_matrix_t matrix) {
    return to_c(from_c(box).transformed(from_c(matrix)));
}

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

// Free a single element handle allocated by wrap_element.
extern "C" void lunasvg_element_destroy(lunasvg_element_t* element) {
    delete element;
}
