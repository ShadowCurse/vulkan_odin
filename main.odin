package vo

import fmt "core:fmt"
import os "core:os"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

WIDTH: i32 : 800
HEIGHT: i32 : 450

VK_VALIDATION_LAYERS_NAMES: []cstring : {"VK_LAYER_KHRONOS_validation"}
VK_DEBUG :: true

vk_check_result :: proc(result: vk.Result) {
    if result != vk.Result.SUCCESS {
        fmt.println("VK resturned error", result)
        os.exit(-1)
    }
}

find_validation_layer :: proc(
    vk_layer_properties: []vk.LayerProperties,
    layer_name: cstring,
) -> bool {
    for i in 0 ..< len(vk_layer_properties) {
        name := cstring(cast(^u8)&vk_layer_properties[i].layerName)
        fmt.println("Checking ", name, "against ", layer_name)
        if name == layer_name {
            return true
        }
    }
    return false
}

glfw_get_proc_address :: proc(p: rawptr, name: cstring) {
    (cast(^rawptr)p)^ = glfw.GetInstanceProcAddress(
        (^vk.Instance)(context.user_ptr)^,
        name,
    )
}

main :: proc() {
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

    window := glfw.CreateWindow(WIDTH, HEIGHT, "VulkanTest", nil, nil)
    defer glfw.DestroyWindow(window)

    glfw_extensions := glfw.GetRequiredInstanceExtensions()
    fmt.println("glfw_extensions num: ", len(glfw_extensions))
    for e in glfw_extensions {
        fmt.println("glfw extension: ", e)
    }

    // The actual instance creation happens lower
    instance := vk.Instance{}

    // needed to load vulkan functions
    context.user_ptr = &instance
    vk.load_proc_addresses(glfw_get_proc_address)

    // looking at the available extensions
    vk_extension_property_count: u32 = 0
    vk_check_result(
        vk.EnumerateInstanceExtensionProperties(
            nil,
            &vk_extension_property_count,
            nil,
        ),
    )
    fmt.println("vk_property_count: ", vk_extension_property_count)
    vk_extension_properties := make(
        []vk.ExtensionProperties,
        vk_extension_property_count,
    )
    defer delete(vk_extension_properties)
    vk_check_result(
        vk.EnumerateInstanceExtensionProperties(
            nil,
            &vk_extension_property_count,
            raw_data(vk_extension_properties),
        ),
    )
    for i in 0 ..< vk_extension_property_count {
        name := cstring(cast(^u8)&vk_extension_properties[i].extensionName)
        spec_version := vk_extension_properties[i].specVersion
        fmt.println(
            "vk extension property name: ",
            name,
            " spec version: ",
            spec_version,
        )
    }

    // looking at the available layers
    vk_layer_property_count: u32 = 0
    vk_check_result(
        vk.EnumerateInstanceLayerProperties(&vk_layer_property_count, nil),
    )
    fmt.println("vk_property_count: ", vk_layer_property_count)
    vk_layer_properties := make([]vk.LayerProperties, vk_layer_property_count)
    defer delete(vk_layer_properties)
    vk_check_result(
        vk.EnumerateInstanceLayerProperties(
            &vk_layer_property_count,
            raw_data(vk_layer_properties),
        ),
    )
    for i in 0 ..< vk_layer_property_count {
        name := cstring(cast(^u8)&vk_layer_properties[i].layerName)
        description := cstring(cast(^u8)&vk_layer_properties[i].description)
        spec_version := vk_layer_properties[i].specVersion
        fmt.println(
            "vk layer property name: ",
            name,
            " spec version: ",
            spec_version,
            " description: ",
            description,
        )
    }

    // Checking that our validation layers are present
    found_all_validation_layers := true
    for name in VK_VALIDATION_LAYERS_NAMES {
        found_all_validation_layers &= find_validation_layer(
            vk_layer_properties,
            name,
        )
    }
    if found_all_validation_layers {
        fmt.println("Found all needed validation layers")
    } else {
        fmt.println("Did not find all needed validation layers")
        os.exit(-1)
    }

    // Creating instance
    vk_app_info := vk.ApplicationInfo {
        sType              = vk.StructureType.APPLICATION_INFO,
        pApplicationName   = "VulkalTest",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        pEngineName        = "NoEngine",
        engineVersion      = vk.MAKE_VERSION(1, 0, 0),
        apiVersion         = vk.API_VERSION_1_3,
        pNext              = nil,
    }

    vk_instance_create_info := vk.InstanceCreateInfo {
        sType                   = vk.StructureType.INSTANCE_CREATE_INFO,
        // flags:                   InstanceCreateFlags,
        pApplicationInfo        = &vk_app_info,
        enabledExtensionCount   = cast(u32)len(glfw_extensions),
        ppEnabledExtensionNames = raw_data(glfw_extensions),
        enabledLayerCount       = cast(u32)len(VK_VALIDATION_LAYERS_NAMES),
        ppEnabledLayerNames     = raw_data(VK_VALIDATION_LAYERS_NAMES),
        pNext                   = nil,
    }

    vk_check_result(
        vk.CreateInstance(&vk_instance_create_info, nil, &instance),
    )
    defer vk.DestroyInstance(instance, nil)

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
    }
}
