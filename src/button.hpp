
#ifndef LOE_BUTTON_H
#define LOE_BUTTON_H

#include <SDL2/SDL.h>

class Button {
 private:
  SDL_Rect src;
  SDL_Renderer* r;
  bool hovering = false;
  bool isclicking = false;

 public:
  static SDL_Texture* texture;
  SDL_Rect position;
  bool disabled = false;

  explicit Button(SDL_Renderer* renderer, int x = 0, int y = 0) {
    r = renderer;
    src.x = 0;
    src.y = 0;
    src.w = 160;
    src.h = 60;
    position.x = x;
    position.y = y;
    position.w = src.w;
    position.h = src.h;
  }
  ~Button() {}
  void render() {
    src.y = (disabled ? 2 : (hovering ? 1 : 0)) * 60;
    // if (disabled) return;
    SDL_RenderCopy(r, Button::texture, &src, &position);
  }
  bool update(int x, int y, Uint32 type) {
    hovering = (x >= position.x && x < position.x + position.w) &&
               (y >= position.y && y < position.y + position.h);
    if (type == SDL_MOUSEBUTTONDOWN && hovering) {
      isclicking = true;
    } else if (type == SDL_MOUSEMOTION && !hovering) {
      isclicking = false;
    } else if (type == SDL_MOUSEBUTTONUP && hovering && isclicking && !disabled) {
      isclicking = false;
      return true;
    }
    return false;
  }
};
SDL_Texture* Button::texture = nullptr;

#endif // LOE_BUTTON_H
