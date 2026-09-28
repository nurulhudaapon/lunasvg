const raw = @import("c");

pub const document_t = raw.lunasvg_document_t;
pub const bitmap_t = raw.lunasvg_bitmap_t;
pub const element_t = raw.lunasvg_element_t;
pub const box_t = raw.lunasvg_box_t;
pub const matrix_t = raw.lunasvg_matrix_t;
pub const write_func_t = raw.lunasvg_write_func_t;
pub const destroy_func_t = raw.lunasvg_destroy_func_t;

pub const version = raw.lunasvg_c_version;
pub const version_string = raw.lunasvg_c_version_string;
pub const add_font_face_from_file = raw.lunasvg_c_add_font_face_from_file;
pub const add_font_face_from_data = raw.lunasvg_c_add_font_face_from_data;

pub const document_load_from_file = raw.lunasvg_document_load_from_file;
pub const document_load_from_data = raw.lunasvg_document_load_from_data;
pub const document_destroy = raw.lunasvg_document_destroy;
pub const document_width = raw.lunasvg_document_width;
pub const document_height = raw.lunasvg_document_height;
pub const document_bounding_box = raw.lunasvg_document_bounding_box;
pub const document_apply_stylesheet = raw.lunasvg_document_apply_stylesheet;
pub const document_update_layout = raw.lunasvg_document_update_layout;
pub const document_force_layout = raw.lunasvg_document_force_layout;
pub const document_render = raw.lunasvg_document_render;
pub const document_render_to_bitmap = raw.lunasvg_document_render_to_bitmap;
pub const document_element_from_point = raw.lunasvg_document_element_from_point;
pub const document_get_element_by_id = raw.lunasvg_document_get_element_by_id;
pub const document_document_element = raw.lunasvg_document_document_element;
pub const document_query_selector_all = raw.lunasvg_document_query_selector_all;
pub const element_list_destroy = raw.lunasvg_element_list_destroy;
pub const element_destroy = raw.lunasvg_element_destroy;

pub const bitmap_create = raw.lunasvg_bitmap_create;
pub const bitmap_create_for_data = raw.lunasvg_bitmap_create_for_data;
pub const bitmap_destroy = raw.lunasvg_bitmap_destroy;
pub const bitmap_data = raw.lunasvg_bitmap_data;
pub const bitmap_width = raw.lunasvg_bitmap_width;
pub const bitmap_height = raw.lunasvg_bitmap_height;
pub const bitmap_stride = raw.lunasvg_bitmap_stride;
pub const bitmap_is_null = raw.lunasvg_bitmap_is_null;
pub const bitmap_clear = raw.lunasvg_bitmap_clear;
pub const bitmap_convert_to_rgba = raw.lunasvg_bitmap_convert_to_rgba;
pub const bitmap_write_to_png_file = raw.lunasvg_bitmap_write_to_png_file;
pub const bitmap_write_to_png = raw.lunasvg_bitmap_write_to_png;

pub const element_is_null = raw.lunasvg_element_is_null;
pub const element_has_attribute = raw.lunasvg_element_has_attribute;
pub const element_get_attribute = raw.lunasvg_element_get_attribute;
pub const element_set_attribute = raw.lunasvg_element_set_attribute;
pub const element_render = raw.lunasvg_element_render;
pub const element_render_to_bitmap = raw.lunasvg_element_render_to_bitmap;
pub const element_get_local_matrix = raw.lunasvg_element_get_local_matrix;
pub const element_get_global_matrix = raw.lunasvg_element_get_global_matrix;
pub const element_get_local_bounding_box = raw.lunasvg_element_get_local_bounding_box;
pub const element_get_global_bounding_box = raw.lunasvg_element_get_global_bounding_box;
pub const element_get_bounding_box = raw.lunasvg_element_get_bounding_box;

pub const matrix_identity = raw.lunasvg_matrix_identity;
pub const matrix_translated = raw.lunasvg_matrix_translated;
pub const matrix_scaled = raw.lunasvg_matrix_scaled;
pub const matrix_rotated = raw.lunasvg_matrix_rotated;
pub const matrix_sheared = raw.lunasvg_matrix_sheared;
pub const matrix_multiply = raw.lunasvg_matrix_multiply;
pub const matrix_translate = raw.lunasvg_matrix_translate;
pub const matrix_scale = raw.lunasvg_matrix_scale;
pub const matrix_rotate = raw.lunasvg_matrix_rotate;
pub const matrix_shear = raw.lunasvg_matrix_shear;
pub const matrix_invert = raw.lunasvg_matrix_invert;
pub const matrix_inverse = raw.lunasvg_matrix_inverse;

pub const box_transformed = raw.lunasvg_box_transformed;
pub const svg_to_png = raw.lunasvg_svg_to_png;
