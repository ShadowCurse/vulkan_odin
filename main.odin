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

record_command_buffer :: proc(
    command_buffer: vk.CommandBuffer,
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    extent: vk.Extent2D,
    graphics_pipeline: vk.Pipeline,
) {
    command_buffer_begin_info := vk.CommandBufferBeginInfo {
        sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
    }
    vk_check_result(
        vk.BeginCommandBuffer(command_buffer, &command_buffer_begin_info),
    )
    render_pass_clear_color := vk.ClearValue {
        color = {float32 = [4]f32{0.0, 0.0, 0.0, 0.0}},
    }
    render_pass_begin_info := vk.RenderPassBeginInfo {
        sType = vk.StructureType.RENDER_PASS_BEGIN_INFO,
        renderPass = render_pass,
        framebuffer = framebuffer,
        renderArea = vk.Rect2D{offset = {0.0, 0.0}, extent = extent},
        clearValueCount = 1,
        pClearValues = &render_pass_clear_color,
    }
    vk.CmdBeginRenderPass(
        command_buffer,
        &render_pass_begin_info,
        vk.SubpassContents.INLINE,
    )
    vk.CmdBindPipeline(
        command_buffer,
        vk.PipelineBindPoint.GRAPHICS,
        graphics_pipeline,
    )
    vk.CmdDraw(command_buffer, 3, 1, 0, 0)
    vk.CmdEndRenderPass(command_buffer)
    vk_check_result(vk.EndCommandBuffer(command_buffer))
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

    graphics_queue_index: Maybe(u32) = nil
    present_queue_index: Maybe(u32) = nil
    for queue_family_index in 0 ..< len(vk_device_queue_families) {
        queue_family := &vk_device_queue_families[queue_family_index]
        if .GRAPHICS in queue_family.queueFlags {
            fmt.println(
                "Queue family ",
                queue_family_index,
                " supports GRAPHICS bit",
            )
            graphics_queue_index = cast(u32)queue_family_index
        } else {
            fmt.println(
                "Queue family ",
                queue_family_index,
                " does not supports GRAPHICS bit",
            )
        }

        queue_family_pesentation_supported: u32
        vk.GetPhysicalDeviceSurfaceSupportKHR(
            vk_physical_device,
            u32(queue_family_index),
            surface,
            cast(^b32)&queue_family_pesentation_supported,
        )
        if cast(bool)queue_family_pesentation_supported {
            fmt.println(
                "Queue family ",
                queue_family_index,
                " supports presentation",
            )
            present_queue_index = cast(u32)queue_family_index
        }

        if graphics_queue_index != nil && present_queue_index != nil {
            break
        }
    }

    fmt.println("Selected graphics queue index: ", graphics_queue_index.(u32))
    fmt.println("Selected present queue index: ", present_queue_index.(u32))
    assert(
        graphics_queue_index.(u32) == present_queue_index.(u32),
        "We assume the families are same",
    )

    fmt.println("Creating device")
    queue_priority: f32 = 1.0
    queue_create_info := vk.DeviceQueueCreateInfo {
        sType            = vk.StructureType.DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex = graphics_queue_index.(u32),
        queueCount       = 1,
        pQueuePriorities = &queue_priority,
    }

    vk_physical_device_features := vk.PhysicalDeviceFeatures{}

    vk_device_create_info := vk.DeviceCreateInfo {
        sType                   = vk.StructureType.DEVICE_CREATE_INFO,
        queueCreateInfoCount    = 1,
        pQueueCreateInfos       = &queue_create_info,
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
        graphics_queue_index.(u32),
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
        initialLayout  = vk.ImageLayout.UNDEFINED,
        finalLayout    = vk.ImageLayout.PRESENT_SRC_KHR,
    }

    render_pass_dependency := vk.SubpassDependency {
        srcSubpass    = vk.SUBPASS_EXTERNAL,
        dstSubpass    = 0,
        srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
        srcAccessMask = {},
        dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
        dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
    }

    render_pass_create_info := vk.RenderPassCreateInfo {
        sType           = vk.StructureType.RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments    = &render_pass_attachment_description,
        subpassCount    = 1,
        pSubpasses      = &subpass_description,
        dependencyCount = 1,
        pDependencies   = &render_pass_dependency,
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

    fmt.println("Creating graphics pipeline")
    pipeline_vertex_input_state_create_info :=
        vk.PipelineVertexInputStateCreateInfo {
            sType                           = vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            vertexBindingDescriptionCount   = 0,
            pVertexBindingDescriptions      = nil,
            vertexAttributeDescriptionCount = 0,
            pVertexAttributeDescriptions    = nil,
        }

    pipeline_input_assembly_state_create_info :=
        vk.PipelineInputAssemblyStateCreateInfo {
            sType                  = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            topology               = vk.PrimitiveTopology.TRIANGLE_LIST,
            primitiveRestartEnable = false,
        }

    pipeline_viewport := vk.Viewport {
            x        = 0.0,
            y        = 0.0,
            width    = f32(vk_swap_chain_extent.width),
            height   = f32(vk_swap_chain_extent.height),
            minDepth = 0.0,
            maxDepth = 1.0,
        }

    pipeline_scissor := vk.Rect2D {
            offset = {0.0, 0.0},
            extent = vk_swap_chain_extent,
        }

    pipeline_viewport_state_create_info := vk.PipelineViewportStateCreateInfo {
            sType         = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            viewportCount = 1,
            pViewports    = &pipeline_viewport,
            scissorCount  = 1,
            pScissors     = &pipeline_scissor,
        }

    pipeline_rasterizer_state_create_info :=
        vk.PipelineRasterizationStateCreateInfo {
            sType                   = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            depthClampEnable        = false,
            rasterizerDiscardEnable = false,
            polygonMode             = vk.PolygonMode.FILL,
            lineWidth               = 1.0,
            cullMode                = {.BACK},
            frontFace               = vk.FrontFace.CLOCKWISE,
            depthBiasEnable         = false,
        }

    pipeline_multisample_state_create_info :=
        vk.PipelineMultisampleStateCreateInfo {
            sType                = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            sampleShadingEnable  = false,
            rasterizationSamples = {._1},
        }

    pipeline_color_blend_attachment_state :=
        vk.PipelineColorBlendAttachmentState {
            colorWriteMask = {.R, .G, .B, .A},
            blendEnable    = false,
        }

    pipeline_color_blend_state_create_info :=
        vk.PipelineColorBlendStateCreateInfo {
            sType           = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            logicOpEnable   = false,
            attachmentCount = 1,
            pAttachments    = &pipeline_color_blend_attachment_state,
        }

    vert_pipeline_shader_stage_create_info :=
        vk.PipelineShaderStageCreateInfo {
            sType  = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage  = {.VERTEX},
            module = vert_shader_module,
            pName  = "main",
        }
    frag_pipeline_shader_stage_create_info :=
        vk.PipelineShaderStageCreateInfo {
            sType  = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage  = {.FRAGMENT},
            module = frag_shader_module,
            pName  = "main",
        }

    pipeline_stages: []vk.PipelineShaderStageCreateInfo = {
        vert_pipeline_shader_stage_create_info,
        frag_pipeline_shader_stage_create_info,
    }

    graphics_pipeline_create_info := vk.GraphicsPipelineCreateInfo {
        sType               = vk.StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount          = 2,
        pStages             = raw_data(pipeline_stages),
        pVertexInputState   = &pipeline_vertex_input_state_create_info,
        pInputAssemblyState = &pipeline_input_assembly_state_create_info,
        pViewportState      = &pipeline_viewport_state_create_info,
        pRasterizationState = &pipeline_rasterizer_state_create_info,
        pMultisampleState   = &pipeline_multisample_state_create_info,
        pColorBlendState    = &pipeline_color_blend_state_create_info,
        pDepthStencilState  = nil,
        pDynamicState       = nil,
        layout              = pipeline_layout,
        renderPass          = render_pass,
        subpass             = 0,
    }

    graphics_pipeline := vk.Pipeline{}
    vk_check_result(
        vk.CreateGraphicsPipelines(
            vk_device,
            0,
            1,
            &graphics_pipeline_create_info,
            nil,
            &graphics_pipeline,
        ),
    )
    defer vk.DestroyPipeline(vk_device, graphics_pipeline, nil)

    fmt.println("Creating frame buffers")
    framebuffers := make([]vk.Framebuffer, vk_swap_chain_images_count)
    for i in 0 ..< len(vk_swap_chain_imagess) {
        framebuffer_create_info := vk.FramebufferCreateInfo {
            sType           = vk.StructureType.FRAMEBUFFER_CREATE_INFO,
            renderPass      = render_pass,
            attachmentCount = 1,
            pAttachments    = &vk_swap_chain_images_views[i],
            width           = vk_swap_chain_extent.width,
            height          = vk_swap_chain_extent.height,
            layers          = 1,
        }

        vk_check_result(
            vk.CreateFramebuffer(
                vk_device,
                &framebuffer_create_info,
                nil,
                &framebuffers[i],
            ),
        )
    }
    defer {
        for f in framebuffers {
            vk.DestroyFramebuffer(vk_device, f, nil)
        }
        delete(framebuffers)
    }

    fmt.println("Creating command pool")
    command_pool_create_info := vk.CommandPoolCreateInfo {
        sType            = vk.StructureType.COMMAND_POOL_CREATE_INFO,
        flags            = {.RESET_COMMAND_BUFFER},
        queueFamilyIndex = graphics_queue_index.(u32),
    }

    command_pool := vk.CommandPool{}
    vk_check_result(
        vk.CreateCommandPool(
            vk_device,
            &command_pool_create_info,
            nil,
            &command_pool,
        ),
    )
    defer vk.DestroyCommandPool(vk_device, command_pool, nil)

    fmt.println("Creating command buffer")
    command_buffer_allocate_info := vk.CommandBufferAllocateInfo {
        sType              = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = command_pool,
        level              = vk.CommandBufferLevel.PRIMARY,
        commandBufferCount = 1,
    }
    command_buffer := vk.CommandBuffer{}
    vk_check_result(
        vk.AllocateCommandBuffers(
            vk_device,
            &command_buffer_allocate_info,
            &command_buffer,
        ),
    )

    semaphore_create_info := vk.SemaphoreCreateInfo {
        sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
    }
    semaphore_image_available := vk.Semaphore{}
    vk_check_result(
        vk.CreateSemaphore(
            vk_device,
            &semaphore_create_info,
            nil,
            &semaphore_image_available,
        ),
    )
    defer vk.DestroySemaphore(vk_device, semaphore_image_available, nil)
    semaphore_render_finished := vk.Semaphore{}
    vk_check_result(
        vk.CreateSemaphore(
            vk_device,
            &semaphore_create_info,
            nil,
            &semaphore_render_finished,
        ),
    )
    defer vk.DestroySemaphore(vk_device, semaphore_render_finished, nil)

    fence_create_info := vk.FenceCreateInfo {
        sType = vk.StructureType.FENCE_CREATE_INFO,
        flags = {.SIGNALED},
    }
    fence_in_flight := vk.Fence{}
    vk_check_result(
        vk.CreateFence(vk_device, &fence_create_info, nil, &fence_in_flight),
    )
    defer vk.DestroyFence(vk_device, fence_in_flight, nil)

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

        vk_check_result(
            vk.WaitForFences(vk_device, 1, &fence_in_flight, true, max(u64)),
        )
        vk_check_result(vk.ResetFences(vk_device, 1, &fence_in_flight))

        image_index: u32 = 0

        vk_check_result(
            vk.AcquireNextImageKHR(
                vk_device,
                vk_swap_chain,
                max(u64),
                semaphore_image_available,
                {},
                &image_index,
            ),
        )

        vk_check_result(vk.ResetCommandBuffer(command_buffer, {}))
        record_command_buffer(
            command_buffer,
            render_pass,
            framebuffers[image_index],
            vk_swap_chain_extent,
            graphics_pipeline,
        )

        wait_semaphores: []vk.Semaphore = {semaphore_image_available}
        wait_stages: []vk.PipelineStageFlags = {{.COLOR_ATTACHMENT_OUTPUT}}
        signal_semaphores: []vk.Semaphore = {semaphore_render_finished}
        submit_info := vk.SubmitInfo {
            sType                = vk.StructureType.SUBMIT_INFO,
            waitSemaphoreCount   = 1,
            pWaitSemaphores      = raw_data(wait_semaphores),
            pWaitDstStageMask    = raw_data(wait_stages),
            commandBufferCount   = 1,
            pCommandBuffers      = &command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = raw_data(signal_semaphores),
        }

        vk_check_result(
            vk.QueueSubmit(
                vk_graphics_queue,
                1,
                &submit_info,
                fence_in_flight,
            ),
        )

        present_info := vk.PresentInfoKHR {
            sType              = vk.StructureType.PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = raw_data(signal_semaphores),
            swapchainCount     = 1,
            pSwapchains        = &vk_swap_chain,
            pImageIndices      = &image_index,
        }

        vk_check_result(vk.QueuePresentKHR(vk_graphics_queue, &present_info))
    }

    vk_check_result(vk.DeviceWaitIdle(vk_device))
}
