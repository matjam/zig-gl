const std = @import("std");
const c = @import("c.zig");
const File = std.fs.File;

pub fn main() anyerror!void {
    std.debug.warn("starting zixel\n", .{});

    if (c.glfwInit() == c.GLFW_FALSE) {
        std.debug.warn("failed to initialize glfw\n", .{});
        return;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    var window = c.glfwCreateWindow(800, 600, "Hello zig", null, null);
    if (window == null) {
        std.debug.warn("failed to create glfw window\n", .{});
        return;
    }

    // Make the window's context current
    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    // Now, glad can be initialized.
    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0) {
        std.debug.warn("unable to init glad\n", .{});
        return;
    }

    // build and compile our shader program
    // ------------------------------------

    var vertexShader = try compileShader("shaders/vertex.glsl", c.GL_VERTEX_SHADER);
    var fragmentShader = try compileShader("shaders/fragment.glsl", c.GL_FRAGMENT_SHADER);
    const shaderProgram = try linkShaders(vertexShader, fragmentShader);

    // vertex data
    var vertices: [9]c.GLfloat = .{
        -0.5, -0.5, 0.0, // left
        0.5,  -0.5, 0.0, // right
        0.0,  0.5,  0.0, // top
    };

    var VBO: c_uint = 0;
    var VAO: c_uint = 0;

    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);
    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    c.glBindVertexArray(VAO);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, 9, &vertices, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    // note that this is allowed, the call to c.glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

    // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to c.glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    c.glBindVertexArray(0);

    std.debug.warn("VBO: {} VAO: {}\n", .{ VBO, VAO });
    c.glBindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized

    // Loop until the user closes the window
    while (c.glfwWindowShouldClose(window) == 0) {
        processInput(window);

        // Clear then render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // draw our first triangle
        c.glUseProgram(shaderProgram);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        // swap the buffers
        c.glfwSwapBuffers(window);

        // Poll for and process events
        c.glfwPollEvents();
    }

    c.glDeleteVertexArrays(1, &VAO);
    c.glDeleteBuffers(1, &VBO);
    c.glDeleteProgram(shaderProgram);
}

fn framebufferSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glViewport(0, 0, width, height);
}

fn processInput(window: ?*c.GLFWwindow) callconv(.C) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
}

fn compileShader(file: []const u8, shader_type: c_uint) !c.GLuint {
    std.debug.warn("shader loading file: {}\n", .{file});

    const source = try std.fs.cwd().readFileAllocOptions(std.heap.c_allocator, file, 1000000, @alignOf(u8), 0);
    defer std.heap.c_allocator.free(source);

    var shader = c.glCreateShader(shader_type);
    c.glShaderSource(shader, 1, &(&source[0]), null);
    c.glCompileShader(shader);

    // check for shader compile errors
    var success: c.GLint = 0;
    var infoLog = [_]u8{0} ** 512;

    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(shader, 512, null, &infoLog);
        std.debug.warn("error compiling shader: {}\n", .{infoLog});
        return error.ShaderCompilerError;
    }

    return shader;
}

fn linkShaders(vertexShader: c.GLuint, fragmentShader: c.GLuint) !c.GLuint {
    std.debug.warn("linking shader program\n", .{});

    // link shaders
    var program = c.glCreateProgram();
    c.glAttachShader(program, vertexShader);
    c.glAttachShader(program, fragmentShader);
    c.glLinkProgram(program);

    // check for linking errors
    var success: c.GLint = 0;
    var infoLog = [_]u8{0} ** 512;

    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(program, 512, null, &infoLog);
        std.debug.warn("error linking shader program: {}\n", .{infoLog});
        return error.ShaderLinkerError;
    }
    c.glDeleteShader(vertexShader);
    c.glDeleteShader(fragmentShader);

    return program;
}
