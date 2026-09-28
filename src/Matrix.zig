const abi = @import("abi.zig");

/// 2D affine transform matrix.
a: f32 = 1,
b: f32 = 0,
c: f32 = 0,
d: f32 = 1,
e: f32 = 0,
f: f32 = 0,

const Matrix = @This();

pub fn identity() Matrix {
    return fromC(abi.matrix_identity());
}

pub fn translated(tx: f32, ty: f32) Matrix {
    return fromC(abi.matrix_translated(tx, ty));
}

pub fn scaled(sx: f32, sy: f32) Matrix {
    return fromC(abi.matrix_scaled(sx, sy));
}

pub fn rotated(angle_degrees: f32, cx: f32, cy: f32) Matrix {
    return fromC(abi.matrix_rotated(angle_degrees, cx, cy));
}

pub fn sheared(shx: f32, shy: f32) Matrix {
    return fromC(abi.matrix_sheared(shx, shy));
}

pub fn fromC(m: abi.matrix_t) Matrix {
    return .{ .a = m.a, .b = m.b, .c = m.c, .d = m.d, .e = m.e, .f = m.f };
}

pub fn toC(self: Matrix) abi.matrix_t {
    return .{ .a = self.a, .b = self.b, .c = self.c, .d = self.d, .e = self.e, .f = self.f };
}

pub fn multiply(self: Matrix, other: Matrix) Matrix {
    return fromC(abi.matrix_multiply(self.toC(), other.toC()));
}

pub fn translate(self: Matrix, tx: f32, ty: f32) Matrix {
    return fromC(abi.matrix_translate(self.toC(), tx, ty));
}

pub fn scale(self: Matrix, sx: f32, sy: f32) Matrix {
    return fromC(abi.matrix_scale(self.toC(), sx, sy));
}

pub fn rotate(self: Matrix, angle_degrees: f32, cx: f32, cy: f32) Matrix {
    return fromC(abi.matrix_rotate(self.toC(), angle_degrees, cx, cy));
}

pub fn shear(self: Matrix, shx: f32, shy: f32) Matrix {
    return fromC(abi.matrix_shear(self.toC(), shx, shy));
}

pub fn invert(self: Matrix) Matrix {
    return fromC(abi.matrix_invert(self.toC()));
}

pub fn inverse(self: Matrix) Matrix {
    return fromC(abi.matrix_inverse(self.toC()));
}
