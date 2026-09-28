#ifndef LUNASVG_C_H
#define LUNASVG_C_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lunasvg_document lunasvg_document_t;
typedef struct lunasvg_bitmap lunasvg_bitmap_t;
typedef struct lunasvg_element lunasvg_element_t;

typedef struct lunasvg_box {
    float x;
    float y;
    float w;
    float h;
} lunasvg_box_t;

typedef struct lunasvg_matrix {
    float a;
    float b;
    float c;
    float d;
    float e;
    float f;
} lunasvg_matrix_t;

typedef void (*lunasvg_write_func_t)(void* closure, void* data, int size);
typedef void (*lunasvg_destroy_func_t)(void* closure);

int lunasvg_c_version(void);
const char* lunasvg_c_version_string(void);

bool lunasvg_c_add_font_face_from_file(const char* family, bool bold, bool italic, const char* filename);
bool lunasvg_c_add_font_face_from_data(
    const char* family,
    bool bold,
    bool italic,
    const void* data,
    size_t length,
    lunasvg_destroy_func_t destroy_func,
    void* closure
);

lunasvg_document_t* lunasvg_document_load_from_file(const char* filename);
lunasvg_document_t* lunasvg_document_load_from_data(const char* data, size_t length);
void lunasvg_document_destroy(lunasvg_document_t* document);

float lunasvg_document_width(const lunasvg_document_t* document);
float lunasvg_document_height(const lunasvg_document_t* document);
lunasvg_box_t lunasvg_document_bounding_box(const lunasvg_document_t* document);

void lunasvg_document_apply_stylesheet(lunasvg_document_t* document, const char* css, size_t length);
void lunasvg_document_update_layout(lunasvg_document_t* document);
void lunasvg_document_force_layout(lunasvg_document_t* document);

void lunasvg_document_render(
    const lunasvg_document_t* document,
    lunasvg_bitmap_t* bitmap,
    const lunasvg_matrix_t* matrix
);
lunasvg_bitmap_t* lunasvg_document_render_to_bitmap(
    const lunasvg_document_t* document,
    int width,
    int height,
    uint32_t background_color
);

lunasvg_element_t* lunasvg_document_element_from_point(const lunasvg_document_t* document, float x, float y);
lunasvg_element_t* lunasvg_document_get_element_by_id(const lunasvg_document_t* document, const char* id, size_t id_len);
lunasvg_element_t* lunasvg_document_document_element(const lunasvg_document_t* document);

lunasvg_element_t** lunasvg_document_query_selector_all(
    const lunasvg_document_t* document,
    const char* selectors,
    size_t selectors_len,
    size_t* out_count
);
void lunasvg_element_list_destroy(lunasvg_element_t** elements);
void lunasvg_element_destroy(lunasvg_element_t* element);

lunasvg_bitmap_t* lunasvg_bitmap_create(int width, int height);
lunasvg_bitmap_t* lunasvg_bitmap_create_for_data(uint8_t* data, int width, int height, int stride);
void lunasvg_bitmap_destroy(lunasvg_bitmap_t* bitmap);

uint8_t* lunasvg_bitmap_data(const lunasvg_bitmap_t* bitmap);
int lunasvg_bitmap_width(const lunasvg_bitmap_t* bitmap);
int lunasvg_bitmap_height(const lunasvg_bitmap_t* bitmap);
int lunasvg_bitmap_stride(const lunasvg_bitmap_t* bitmap);
bool lunasvg_bitmap_is_null(const lunasvg_bitmap_t* bitmap);
void lunasvg_bitmap_clear(lunasvg_bitmap_t* bitmap, uint32_t color);
void lunasvg_bitmap_convert_to_rgba(lunasvg_bitmap_t* bitmap);
bool lunasvg_bitmap_write_to_png_file(const lunasvg_bitmap_t* bitmap, const char* filename);
bool lunasvg_bitmap_write_to_png(
    const lunasvg_bitmap_t* bitmap,
    lunasvg_write_func_t write_func,
    void* closure
);

bool lunasvg_element_is_null(const lunasvg_element_t* element);
bool lunasvg_element_has_attribute(const lunasvg_element_t* element, const char* name, size_t name_len);
const char* lunasvg_element_get_attribute(
    const lunasvg_element_t* element,
    const char* name,
    size_t name_len,
    size_t* out_len
);
void lunasvg_element_set_attribute(
    lunasvg_element_t* element,
    const char* name,
    size_t name_len,
    const char* value,
    size_t value_len
);

void lunasvg_element_render(
    const lunasvg_element_t* element,
    lunasvg_bitmap_t* bitmap,
    const lunasvg_matrix_t* matrix
);
lunasvg_bitmap_t* lunasvg_element_render_to_bitmap(
    const lunasvg_element_t* element,
    int width,
    int height,
    uint32_t background_color
);

lunasvg_matrix_t lunasvg_element_get_local_matrix(const lunasvg_element_t* element);
lunasvg_matrix_t lunasvg_element_get_global_matrix(const lunasvg_element_t* element);
lunasvg_box_t lunasvg_element_get_local_bounding_box(const lunasvg_element_t* element);
lunasvg_box_t lunasvg_element_get_global_bounding_box(const lunasvg_element_t* element);
lunasvg_box_t lunasvg_element_get_bounding_box(const lunasvg_element_t* element);

lunasvg_matrix_t lunasvg_matrix_identity(void);
lunasvg_matrix_t lunasvg_matrix_translated(float tx, float ty);
lunasvg_matrix_t lunasvg_matrix_scaled(float sx, float sy);
lunasvg_matrix_t lunasvg_matrix_rotated(float angle, float cx, float cy);
lunasvg_matrix_t lunasvg_matrix_sheared(float shx, float shy);
lunasvg_matrix_t lunasvg_matrix_multiply(lunasvg_matrix_t lhs, lunasvg_matrix_t rhs);
lunasvg_matrix_t lunasvg_matrix_translate(lunasvg_matrix_t matrix, float tx, float ty);
lunasvg_matrix_t lunasvg_matrix_scale(lunasvg_matrix_t matrix, float sx, float sy);
lunasvg_matrix_t lunasvg_matrix_rotate(lunasvg_matrix_t matrix, float angle, float cx, float cy);
lunasvg_matrix_t lunasvg_matrix_shear(lunasvg_matrix_t matrix, float shx, float shy);
lunasvg_matrix_t lunasvg_matrix_invert(lunasvg_matrix_t matrix);
lunasvg_matrix_t lunasvg_matrix_inverse(lunasvg_matrix_t matrix);

lunasvg_box_t lunasvg_box_transformed(lunasvg_box_t box, lunasvg_matrix_t matrix);

bool lunasvg_svg_to_png(
    const char* svg_data,
    size_t svg_len,
    int width,
    int height,
    uint32_t background_color,
    lunasvg_write_func_t write_func,
    void* closure
);

#ifdef __cplusplus
}
#endif

#endif /* LUNASVG_C_H */
