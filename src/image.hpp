#ifndef LOE_IMAGE_H
#define LOE_IMAGE_H

#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>

class Image {
 private:
  SDL_Rect dst;
  SDL_Renderer* r;
  SDL_Texture* texture = nullptr;

 public:
  int width = 0;
  int height = 0;
  Image(SDL_Renderer* renderer, const char* imagepath) {
    r = renderer;
    texture = IMG_LoadTexture(r, imagepath);
    if (!texture) {
      printf("IMG_Load: %s\n", IMG_GetError());
      // handle error
    }
    SDL_QueryTexture(texture, nullptr, nullptr, &width, &height);
  }
  ~Image() {
    SDL_DestroyTexture(texture);
  }
  void render(int x, int y, float scale = 1.0, float alpha = 1.0) {
    dst.x = x;  // - (width * scale - width) / 2.0;
    dst.y = y;  // - (height * scale - height) / 2.0;
    dst.w = width;  // * scale;
    dst.h = height;  // * scale;
    // printf("%dx%d %dx%d with scale %f to %dx%d\n", x, y, width, height, scale, dst.x, dst.y);
    SDL_RenderSetScale(r, scale, scale);
    SDL_SetTextureAlphaMod(texture, 255 * alpha);
    SDL_RenderCopy(r, texture, NULL, &dst);
    SDL_RenderSetScale(r, 1.0, 1.0);
  }
};

#endif // LOE_IMAGE_H
