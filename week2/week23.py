import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import os
import subprocess
import sys

# ==============================================
# 四种菌种特性 可以根据需求调整参数
# 格式：[编号, 颜色, 生长速度, 竞争力, 抑制数组, 耐贫瘠, 营养消耗]
#毛霉
#根霉
#曲霉
#青霉
# ==============================================
species_0 = np.array([0, [0.0, 0.6, 0.4], 0.18, 0.9, np.array([0.0, 0.5, 0.4, 0.3]), 0.5, 2.2], dtype=object)
species_1 = np.array([1, [0.8, 0.1, 0.1], 0.16, 0.8, np.array([0.6, 0.0, 0.5, 0.3]), 0.52, 2.0], dtype=object)
species_2 = np.array([2, [0.6, 0.0, 0.8], 0.14, 0.7, np.array([0.6, 0.5, 0.0, 0.5]), 0.81, 1.0], dtype=object)
species_3 = np.array([3, [0.9, 0.7, 0.0], 0.12, 0.6, np.array([1.2, 1.1, 0.8, 0.0]), 1, 1.2], dtype=object)

# ==============================================
# 环境参数
# ==============================================
BREAD_WIDTH = 60
BREAD_HEIGHT = 60
N0 = 100.0#营养值

nutrition_grid = np.full((BREAD_HEIGHT, BREAD_WIDTH), N0, dtype=float)#格子营养参数
species_grid = np.full((BREAD_HEIGHT, BREAD_WIDTH), -1, dtype=int)#格子菌种状态参数

# ==============================================
# 放菌 可根据需求调整 
# ==============================================
#格式[数量,x,y,种类]
spawn_events = [
    [0, 10, 10, 0],
    [0, 10, 50, 1],
    [0, 50, 50, 2],
    [0, 50, 10, 3]
]

# ==============================================
# 初始化
# ==============================================
def init_world():
    global nutrition_grid, species_grid
    nutrition_grid = np.full((BREAD_HEIGHT, BREAD_WIDTH), N0)
    species_grid = np.full((BREAD_HEIGHT, BREAD_WIDTH), -1)

def spawn_molds(current_tick):
    global species_grid
    for t, y, x, sp_id in spawn_events:
        if current_tick == t:
            if 0 <= y < BREAD_HEIGHT and 0 <= x < BREAD_WIDTH:
                species_grid[y, x] = sp_id

# ==============================================
# 扩散
# ==============================================
def diffuse_step():
    global nutrition_grid, species_grid
    old_grid = species_grid.copy()
    new_grid = old_grid.copy()
    species_list = [species_0, species_1, species_2, species_3]
    total_sp = 4

    for y in range(BREAD_HEIGHT):
        for x in range(BREAD_WIDTH):
            current = old_grid[y, x]
            neighbor_cnt = np.zeros(total_sp, dtype=int)

            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < BREAD_HEIGHT and 0 <= nx < BREAD_WIDTH:
                        sp = old_grid[ny, nx]
                        if sp != -1:
                            neighbor_cnt[sp] += 1

            if np.sum(neighbor_cnt) == 0:
                continue

            nutrition = nutrition_grid[y, x]
            power = np.zeros(total_sp, dtype=float)

            for i in range(total_sp):
                s = species_list[i]
                strength = s[3]
                inhibit = s[4]
                tolerance = s[5]
                self_cnt = neighbor_cnt[i]

                base = strength * self_cnt
                for j in range(total_sp):
                    if i != j:
                        base -= inhibit[j] * neighbor_cnt[j]

                if nutrition <= 0:
                    nf = 0.0
                else:
                    nf = (nutrition / N0) ** (1.0 / tolerance)
                power[i] = base * nf

            valid = [i for i in range(total_sp) if power[i] > 0 and neighbor_cnt[i] > 0]
            if not valid:
                continue
            dominant = max(valid, key=lambda a: power[a])

            if current == -1:
                if np.random.rand() < species_list[dominant][2]:
                    new_grid[y, x] = dominant
            else:
                if dominant != current:
                    if np.random.rand() < species_list[dominant][2]:
                        new_grid[y, x] = dominant

    species_grid = new_grid

# ==============================================
# 营养消耗
# ==============================================
def consume_nutrition():
    global nutrition_grid, species_grid
    species_list = [species_0, species_1, species_2, species_3]
    for y in range(BREAD_HEIGHT):
        for x in range(BREAD_WIDTH):
            sid = species_grid[y, x]
            if sid == -1:
                continue
            nutrition_grid[y, x] = max(0.0, nutrition_grid[y, x] - species_list[sid][6])

# ==============================================
# 营养耗尽方格
# ==============================================
def get_exhausted_cells():
    exhausted = []
    for y in range(BREAD_HEIGHT):
        for x in range(BREAD_WIDTH):
            if nutrition_grid[y, x] <= 0:
                exhausted.append((y, x))
    return exhausted

# ==============================================
# 画蓝色分隔线
# 条件：菌种不同 或 死活不同
# ==============================================
def get_blue_edge_lines():
    segs = []
    # 检查右邻居 → 画竖直分隔线
    for y in range(BREAD_HEIGHT):
        for x in range(BREAD_WIDTH - 1):
            sp1 = species_grid[y, x]
            sp2 = species_grid[y, x+1]
            dead1 = (nutrition_grid[y, x] <= 0)
            dead2 = (nutrition_grid[y, x+1] <= 0)
            if sp1 != sp2 or dead1 != dead2:
                # 竖线：(x+0.5,y-0.5) → (x+0.5,y+0.5)
                segs.append(((x+0.5, y-0.5), (x+0.5, y+0.5)))

    # 检查下邻居 → 画水平分隔线
    for y in range(BREAD_HEIGHT - 1):
        for x in range(BREAD_WIDTH):
            sp1 = species_grid[y, x]
            sp2 = species_grid[y+1, x]
            dead1 = (nutrition_grid[y, x] <= 0)
            dead2 = (nutrition_grid[y+1, x] <= 0)
            if sp1 != sp2 or dead1 != dead2:
                # 横线：(x-0.5,y+0.5) → (x+0.5,y+0.5)
                segs.append(((x-0.5, y+0.5), (x+0.5, y+0.5)))
    return segs

# ==============================================
# 动画
# ==============================================
def create_animation(frames, exhausted_frames, edge_line_frames):
    species_list = [species_0, species_1, species_2, species_3]
    colors = [[1,1,1], species_list[0][1], species_list[1][1], species_list[2][1], species_list[3][1]]
    cmap = plt.cm.colors.ListedColormap(colors)

    fig, ax = plt.subplots(figsize=(6,6), dpi=100)
    ax.set_xlim(-0.5, BREAD_WIDTH-0.5)
    ax.set_ylim(BREAD_HEIGHT-0.5, -0.5)
    ax.axis('off')
    im = ax.imshow(frames[0], cmap=cmap, vmin=-1, vmax=3)
    cross_plot, = ax.plot([], [], 'rx', markersize=3, markeredgewidth=1)

    edge_artists = []

    def update(frame):
        im.set_data(frames[frame])
        yx = exhausted_frames[frame]
        if yx:
            ys, xs = zip(*yx)
            cross_plot.set_data(xs, ys)
        else:
            cross_plot.set_data([], [])

        for a in edge_artists:
            a.remove()
        edge_artists.clear()

        segs = edge_line_frames[frame]
        for (x1,y1),(x2,y2) in segs:
            L, = ax.plot([x1,x2],[y1,y2],color='blue',lw=0.7)
            edge_artists.append(L)

        ax.set_title(f"Tick {frame}")
        return [im, cross_plot] + edge_artists

    ani = animation.FuncAnimation(fig, update, frames=len(frames), interval=100, blit=True)
    gif_path = os.path.abspath("mold_grid_edge_lines.gif")
    ani.save(gif_path, writer="pillow")
    plt.close(fig)
    print("已保存：", gif_path)

# ==============================================
# 主循环
# ==============================================
def run_simulation(total_ticks):
    init_world()
    frames = []
    exhausted_frames = []
    edge_line_frames = []

    for tick in range(total_ticks):
        spawn_molds(tick)
        diffuse_step()
        consume_nutrition()
        exhausted = get_exhausted_cells()
        edges = get_blue_edge_lines()

        frames.append(species_grid.copy())
        exhausted_frames.append(exhausted)
        edge_line_frames.append(edges)
        print(f"Tick {tick}")

    create_animation(frames, exhausted_frames, edge_line_frames)

if __name__ == "__main__":
    run_simulation(170)#步数
