package vo

import fmt "core:fmt"
import mem "core:mem"
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

select_swap_extent :: proc(
    cap: vk.SurfaceCapabilitiesKHR,
    window: glfw.WindowHandle,
) -> vk.Extent2D {
    if cap.currentExtent.width != max(u32) {
        return cap.currentExtent
    } else {
        w, h := glfw.GetFramebufferSize(window)
        width := clamp(
            u32(w),
            cap.minImageExtent.width,
            cap.maxImageExtent.width,
        )
        height := clamp(
            u32(h),
            cap.minImageExtent.height,
            cap.maxImageExtent.height,
        )
        return vk.Extent2D{width = width, height = height}
    }

}

load_shader :: proc(path: string) -> []byte {
    handle, open_err := os.open(path)
    if open_err != os.ERROR_NONE {
        fmt.println("Cannot open ", path, " shader")
        os.exit(-1)
    }

    length, size_err := os.file_size(handle)
    if size_err != os.ERROR_NONE {
        fmt.println("Cannot get size of ", path, " shader")
        os.exit(-1)
    }

    // Need to align to 4 bytes for shader module
    data, _ := mem.make_aligned([]byte, length, align_of(u32))

    bytes_read, read_err := os.read_full(handle, data)
    if read_err != os.ERROR_NONE {
        delete(data)
        fmt.println("Cannot read ", path, " shader")
        os.exit(-1)
    }
    return data[:bytes_read]
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

    fmt.println("Looking at the available extensions")
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

    fmt.println("Looking at the available layers")
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

    fmt.println("Checking that our validation layers are present")
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

    fmt.println("Creating instance")
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

    fmt.println("Creating surface")
    surface := vk.SurfaceKHR{}
    vk_check_result(
        glfw.CreateWindowSurface(vk_instance, window, nil, &surface),
    )
    defer vk.DestroySurfaceKHR(vk_instance, surface, nil)

    fmt.println("Selecting physical device")
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

    fmt.println("Getting physical device properties and features")
    properties := vk.PhysicalDeviceProperties{}
    features := vk.PhysicalDeviceFeatures{}
    vk.GetPhysicalDeviceProperties(vk_physical_device, &properties)
    vk.GetPhysicalDeviceFeatures(vk_physical_device, &features)
    fmt.println("Device has type ", properties.deviceType)


    fmt.println("Getting physical device extensions")
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

    fmt.println("Getting physical device queue family properties")
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

    fmt.println("Creating device")
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

    fmt.println("Creating device queue")
    vk_graphics_queue := vk.Queue{}
    vk.GetDeviceQueue(
        vk_device,
        vk_selected_queue_index,
        0,
        &vk_graphics_queue,
    )

    fmt.println("Getting device surface capabilities")
    vk_surface_capabilities := vk.SurfaceCapabilitiesKHR{}
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
        vk_physical_device,
        surface,
        &vk_surface_capabilities,
    )
    fmt.println(
        "physical device surface capabilities",
        vk_surface_capabilities,
    )

    fmt.println("Getting device surface formats")
    vk_device_surface_format_count: u32 = 0
    vk.GetPhysicalDeviceSurfaceFormatsKHR(
        vk_physical_device,
        surface,
        &vk_device_surface_format_count,
        nil,
    )
    vk_device_surface_formats := make(
        []vk.SurfaceFormatKHR,
        vk_device_queue_family_count,
    )
    defer delete(vk_device_surface_formats)
    vk.GetPhysicalDeviceSurfaceFormatsKHR(
        vk_physical_device,
        surface,
        &vk_device_surface_format_count,
        raw_data(vk_device_surface_formats),
    )
    fmt.println(
        "Found ",
        vk_device_surface_format_count,
        " physical devices surface formats:",
        vk_device_surface_formats,
    )

    fmt.println("Getting device surface present modes")
    vk_device_surface_present_modes_count: u32 = 0
    vk.GetPhysicalDeviceSurfacePresentModesKHR(
        vk_physical_device,
        surface,
        &vk_device_surface_present_modes_count,
        nil,
    )
    vk_device_surface_present_formats := make(
        []vk.PresentModeKHR,
        vk_device_queue_family_count,
    )
    defer delete(vk_device_surface_present_formats)
    vk.GetPhysicalDeviceSurfacePresentModesKHR(
        vk_physical_device,
        surface,
        &vk_device_surface_present_modes_count,
        raw_data(vk_device_surface_present_formats),
    )
    fmt.println(
        "Found ",
        vk_device_surface_present_modes_count,
        " physical devices surface present formats:",
        vk_device_surface_present_formats,
    )

    fmt.println("Creating swap chain")
    vk_swap_chain_extent := select_swap_extent(vk_surface_capabilities, window)
    vk_swapchain_create_info := vk.SwapchainCreateInfoKHR {
        sType            = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR,
        surface          = surface,
        minImageCount    = vk_surface_capabilities.minImageCount + 1,
        // format = "B8G8R8A8_SRGB", colorSpace = "SRGB_NONLINEAR"
        imageFormat      = vk_device_surface_formats[1].format,
        imageColorSpace  = vk_device_surface_formats[1].colorSpace,
        imageExtent      = vk_swap_chain_extent,
        imageArrayLayers = 1,
        imageUsage       = {.COLOR_ATTACHMENT},
        imageSharingMode = vk.SharingMode.EXCLUSIVE,
        preTransform     = vk_surface_capabilities.currentTransform,
        compositeAlpha   = {.OPAQUE},
        // mailbox
        presentMode      = vk_device_surface_present_formats[1],
        clipped          = true,
        oldSwapchain     = vk.SwapchainKHR{},
    }

    vk_swap_chain := vk.SwapchainKHR{}
    vk_check_result(
        vk.CreateSwapchainKHR(
            vk_device,
            &vk_swapchain_create_info,
            nil,
            &vk_swap_chain,
        ),
    )
    defer vk.DestroySwapchainKHR(vk_device, vk_swap_chain, nil)

    fmt.println("Getting swap chain images")
    vk_swap_chain_images_count: u32 = 0
    vk.GetSwapchainImagesKHR(
        vk_device,
        vk_swap_chain,
        &vk_swap_chain_images_count,
        nil,
    )
    vk_swap_chain_imagess := make([]vk.Image, vk_swap_chain_images_count)
    defer delete(vk_swap_chain_imagess)
    vk.GetSwapchainImagesKHR(
        vk_device,
        vk_swap_chain,
        &vk_swap_chain_images_count,
        raw_data(vk_swap_chain_imagess),
    )
    fmt.println("Got ", vk_swap_chain_images_count, " swap chain images")

    fmt.println("Creating swap chain image views")
    vk_swap_chain_images_views := make(
        []vk.ImageView,
        vk_swap_chain_images_count,
    )
    for i in 0 ..< len(vk_swap_chain_imagess) {
        vk_image_view_create_info := vk.ImageViewCreateInfo {
            sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO,
            image = vk_swap_chain_imagess[i],
            viewType = vk.ImageViewType.D2,
            format = vk_device_surface_formats[1].format,
            components = vk.ComponentMapping {
                r = vk.ComponentSwizzle.IDENTITY,
                g = vk.ComponentSwizzle.IDENTITY,
                b = vk.ComponentSwizzle.IDENTITY,
                a = vk.ComponentSwizzle.IDENTITY,
            },
            subresourceRange = vk.ImageSubresourceRange {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        vk_check_result(
            vk.CreateImageView(
                vk_device,
                &vk_image_view_create_info,
                nil,
                &vk_swap_chain_images_views[i],
            ),
        )
    }
    defer {
        for view in vk_swap_chain_images_views {
            vk.DestroyImageView(vk_device, view, nil)
        }
        delete(vk_swap_chain_images_views)
    }
    fmt.println("Got ", vk_swap_chain_images_count, " swap chain image views")

    fmt.println("Creating vertex shader module")
    vert_data := load_shader("vert.spv")
    defer delete(vert_data)
    vert_shader_module_create_info := vk.ShaderModuleCreateInfo {
        sType    = vk.StructureType.SHADER_MODULE_CREATE_INFO,
        codeSize = len(vert_data),
        pCode    = transmute(^u32)raw_data(vert_data),
    }
    vert_shader_module := vk.ShaderModule{}
    vk_check_result(
        vk.CreateShaderModule(
            vk_device,
            &vert_shader_module_create_info,
            nil,
            &vert_shader_module,
        ),
    )
    defer vk.DestroyShaderModule(vk_device, vert_shader_module, nil)

    fmt.println("Creating fragment shader module")
    frag_data := load_shader("frag.spv")
    defer delete(frag_data)
    frag_shader_module_create_info := vk.ShaderModuleCreateInfo {
        sType    = vk.StructureType.SHADER_MODULE_CREATE_INFO,
        codeSize = len(frag_data),
        pCode    = transmute(^u32)raw_data(frag_data),
    }
    frag_shader_module := vk.ShaderModule{}
    vk_check_result(
        vk.CreateShaderModule(
            vk_device,
            &frag_shader_module_create_info,
            nil,
            &frag_shader_module,
        ),
    )
    defer vk.DestroyShaderModule(vk_device, frag_shader_module, nil)

    fmt.println("Creating pipeline layout")
    pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
        sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO,
    }

    pipeline_layout := vk.PipelineLayout{}
    vk_check_result(
        vk.CreatePipelineLayout(
            vk_device,
            &pipeline_layout_create_info,
            nil,
            &pipeline_layout,
        ),
    )
    defer vk.DestroyPipelineLayout(vk_device, pipeline_layout, nil)

    fmt.println("Creating render pass")
    subpass_attachment_reference := vk.AttachmentReference {
        attachment = 0,
        layout     = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass_description := vk.SubpassDescription {
        pipelineBindPoint    = vk.PipelineBindPoint.GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments    = &subpass_attachment_reference,
    }

    render_pass_attachment_description := vk.AttachmentDescription {
        format         = vk_device_surface_formats[1].format,
        samples        = {._1},
        loadOp         = vk.AttachmentLoadOp.LOAD,
        storeOp        = vk.AttachmentStoreOp.STORE,
        stencilLoadOp  = vk.AttachmentLoadOp.DONT_CARE,
        stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
        initialLayout  = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
        finalLayout    = vk.ImageLayout.PRESENT_SRC_KHR,
    }

    render_pass_create_info := vk.RenderPassCreateInfo {
        sType           = vk.StructureType.RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments    = &render_pass_attachment_description,
        subpassCount    = 1,
        pSubpasses      = &subpass_description,
    }

    render_pass := vk.RenderPass{}
    vk_check_result(
        vk.CreateRenderPass(
            vk_device,
            &render_pass_create_info,
            nil,
            &render_pass,
        ),
    )
    defer vk.DestroyRenderPass(vk_device, render_pass, nil)
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
    }
}
