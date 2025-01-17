#pragma once

#include <vulkan/vulkan.h>
#include <vulkan/vulkan_metal.h>

#include <vector>

class Buffer;
class Context;
class Headset;
class Pipeline;
class RenderProcess;

class Renderer final
{
public:
  Renderer();
  Renderer(const Context* context, const Headset* headset, MTLTexture_id* tex_l, MTLTexture_id* tex_r, uint32_t tex_w, uint32_t tex_h);
  ~Renderer();

  void render(size_t swapchainImageIndex, int which);
  void submit(bool useSemaphores, int which) const;

  bool isValid() const;
  VkCommandBuffer getCurrentCommandBuffer() const;
  VkSemaphore getCurrentDrawableSemaphore() const;
  VkSemaphore getCurrentPresentableSemaphore() const;
  void createTextureImageHax_L(const Context* context, int which);

  void createTextureImageHax_R(const Context* context, int which);

  VkCommandBuffer beginSingleTimeCommands(const Context* context);
  void endSingleTimeCommands(const Context* context, VkCommandBuffer commandBuffer);
  void transitionImageLayout(const Context* context, VkImage image, VkFormat format, VkImageLayout oldLayout, VkImageLayout newLayout);
  void copyBufferToImage(const Context* context, VkBuffer buffer, VkImage image, uint32_t width, uint32_t height);

  MTLTexture_id metal_tex_l[3];
  MTLTexture_id metal_tex_r[3];
  VkEvent metalTexEvent[3];
  uint32_t metal_tex_w;
  uint32_t metal_tex_h;

private:
  bool valid = true;

  const Context* context = nullptr;
  const Headset* headset = nullptr;

  VkCommandPool commandPool = nullptr;
  std::vector<RenderProcess*> renderProcesses;
  size_t currentRenderProcessIndex = 0u;

  VkImage textureImage_L[3];

  VkImage textureImage_R[3];
};