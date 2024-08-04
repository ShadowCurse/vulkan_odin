package vo

import fmt "core:fmt"
import os "core:os"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

WIDTH: i32 : 800
HEIGHT: i32 : 450

VK_VALIDATION_LAYERS_NAMES: []cstring : {"VK_LAYER_KHRONOS_validation"}
VK_DEVICE_EXTENSION_NAMES: []cstring : {"VK_KHR_swapchain"}
VK_DEBUG :: true

vk_check_result :: proc(result: vk.Result) {
    if result != vk.Result.SUCCESS {
        fmt.eprintln("VK resturned error", result)
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

find_physical_device_extension :: proc(
    vk_extensions: []vk.ExtensionProperties,
    extension_name: cstring,
) -> bool {
    for i in 0 ..< len(vk_extensions) {
        name := cstring(cast(^u8)&vk_extensions[i].extensionName)
        fmt.println("Checking ", name, "against ", extension_name)
        if name == extension_name {
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
    vk_instance := vk.Instance{}

    // needed to load vulkan functions
    context.user_ptr = &vk_instance
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
        vk.CreateInstance(&vk_instance_create_info, nil, &vk_instance),
    )
    defer vk.DestroyInstance(vk_instance, nil)

    // Create surface
    surface := vk.SurfaceKHR{}
    vk_check_result(
        glfw.CreateWindowSurface(vk_instance, window, nil, &surface),
    )
    defer vk.DestroySurfaceKHR(vk_instance, surface, nil)

    // Selecting physical device
    vk_physical_device_count: u32 = 0
    vk_check_result(
        vk.EnumeratePhysicalDevices(
            vk_instance,
            &vk_physical_device_count,
            nil,
        ),
    )
    fmt.println("Found ", vk_physical_device_count, " physical devices")
    vk_physical_devices := make([]vk.PhysicalDevice, vk_physical_device_count)
    defer delete(vk_physical_devices)
    vk_check_result(
        vk.EnumeratePhysicalDevices(
            vk_instance,
            &vk_physical_device_count,
            raw_data(vk_physical_devices),
        ),
    )
    if vk_physical_device_count == 0 {
        fmt.println("Did not find any devices")
        os.exit(-1)
    } else {
        fmt.println("Selecting first physical device")
    }
    vk_physical_device := vk_physical_devices[0]

    properties := vk.PhysicalDeviceProperties{}
    features := vk.PhysicalDeviceFeatures{}
    vk.GetPhysicalDeviceProperties(vk_physical_device, &properties)
    vk.GetPhysicalDeviceFeatures(vk_physical_device, &features)
    fmt.println("Device has type ", properties.deviceType)


    vk_physical_device_extensions_count: u32 = 0
    vk.EnumerateDeviceExtensionProperties(
        vk_physical_device,
        nil,
        &vk_physical_device_extensions_count,
        nil,
    )
    vk_physical_device_extensions := make(
        []vk.ExtensionProperties,
        vk_physical_device_extensions_count,
    )
    defer delete(vk_physical_device_extensions)
    vk.EnumerateDeviceExtensionProperties(
        vk_physical_device,
        nil,
        &vk_physical_device_extensions_count,
        raw_data(vk_physical_device_extensions),
    )
    found_all_device_extensions := true
    for name in VK_DEVICE_EXTENSION_NAMES {
        found_all_device_extensions &= find_physical_device_extension(
            vk_physical_device_extensions,
            name,
        )
    }
    if found_all_device_extensions {
        fmt.println("Found all needed device extensions")
    } else {
        fmt.println("Did not find all needed device extensions")
        os.exit(-1)
    }

    vk_device_queue_family_count: u32 = 0
    vk.GetPhysicalDeviceQueueFamilyProperties(
        vk_physical_device,
        &vk_device_queue_family_count,
        nil,
    )
    fmt.println("Found ", vk_physical_device_count, " physical devices")
    vk_device_queue_families := make(
        []vk.QueueFamilyProperties,
        vk_device_queue_family_count,
    )
    defer delete(vk_device_queue_families)
    vk.GetPhysicalDeviceQueueFamilyProperties(
        vk_physical_device,
        &vk_device_queue_family_count,
        raw_data(vk_device_queue_families),
    )
    vk_selected_queue_index: u32 = 0

    selected_queue_pesentation_supported: u32
    vk.GetPhysicalDeviceSurfaceSupportKHR(
        vk_physical_device,
        vk_selected_queue_index,
        surface,
        cast(^b32)&selected_queue_pesentation_supported,
    )
    fmt.println(
        "Selected queue can present: ",
        cast(bool)selected_queue_pesentation_supported,
    )
    for queue_family_index in 0 ..< len(vk_device_queue_families) {
        queue_family := &vk_device_queue_families[queue_family_index]
        if .GRAPHICS in queue_family.queueFlags {
            fmt.println(
                "Queue family ",
                queue_family_index,
                " supports GRAPHICS bit",
            )
            vk_selected_queue_index = cast(u32)queue_family_index
        } else {
            fmt.println(
                "Queue family ",
                queue_family_index,
                " does not supports GRAPHICS bit",
            )
        }
    }

    vk_queue_priority: f32 = 1.0
    vk_queue_create_info := vk.DeviceQueueCreateInfo {
        sType            = vk.StructureType.DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex = vk_selected_queue_index,
        queueCount       = 1,
        pQueuePriorities = &vk_queue_priority,
    }

    vk_physical_device_features := vk.PhysicalDeviceFeatures{}

    vk_device_create_info := vk.DeviceCreateInfo {
        sType                   = vk.StructureType.DEVICE_CREATE_INFO,
        pQueueCreateInfos       = &vk_queue_create_info,
        queueCreateInfoCount    = 1,
        pEnabledFeatures        = &vk_physical_device_features,
        ppEnabledExtensionNames = raw_data(VK_DEVICE_EXTENSION_NAMES),
        enabledExtensionCount   = u32(len(VK_DEVICE_EXTENSION_NAMES)),
    }

    vk_device := vk.Device{}
    vk_check_result(
        vk.CreateDevice(
            vk_physical_device,
            &vk_device_create_info,
            nil,
            &vk_device,
        ),
    )
    defer vk.DestroyDevice(vk_device, nil)

    vk_graphics_queue := vk.Queue{}
    vk.GetDeviceQueue(
        vk_device,
        vk_selected_queue_index,
        0,
        &vk_graphics_queue,
    )

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
    }
}
