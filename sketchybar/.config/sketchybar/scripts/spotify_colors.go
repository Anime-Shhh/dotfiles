package main

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"net/http"
	"os/exec"
	"strings"
)

func runAppleScript(script string) (string, error) {
	cmd := exec.Command("osascript", "-e", script)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	return strings.TrimSpace(out.String()), err
}

func getArtworkURL() (string, error) {
	return runAppleScript(`tell application "Spotify"
		if player state is playing then
			return artwork url of current track
		end if
	end tell`)
}

/* ---------- HAZY-STYLE COLOR LOGIC ---------- */

func brightness(c color.RGBA) float64 {
	return 0.299*float64(c.R) + 0.587*float64(c.G) + 0.114*float64(c.B)
}

func isTooDark(c color.RGBA) bool {
	return brightness(c) < 100
}

func isTooCloseToWhite(c color.RGBA) bool {
	return c.R > 200 && c.G > 200 && c.B > 200
}

func isUsable(c color.RGBA) bool {
	return !isTooDark(c) && !isTooCloseToWhite(c)
}

func darken(c color.RGBA, factor float64) color.RGBA {
	return color.RGBA{
		R: uint8(float64(c.R) * factor),
		G: uint8(float64(c.G) * factor),
		B: uint8(float64(c.B) * factor),
		A: 255,
	}
}

func readableTextColor(bg color.RGBA) color.RGBA {
	if brightness(bg) > 140 {
		return color.RGBA{R: 20, G: 20, B: 20, A: 255}
	}
	return color.RGBA{R: 240, G: 240, B: 240, A: 255}
}

/*
DOMINANT COLOR
Histogram-based, Hazy-style filtering + fallback
*/
func dominantColor(img image.Image) color.RGBA {
	bounds := img.Bounds()
	hist := make(map[color.RGBA]int)

	// Pass 1: filtered
	for y := bounds.Min.Y; y < bounds.Max.Y; y += 5 {
		for x := bounds.Min.X; x < bounds.Max.X; x += 5 {
			r16, g16, b16, _ := img.At(x, y).RGBA()
			c := color.RGBA{
				R: uint8(r16 >> 8),
				G: uint8(g16 >> 8),
				B: uint8(b16 >> 8),
				A: 255,
			}
			if !isUsable(c) {
				continue
			}
			hist[c]++
		}
	}

	// Fallback: no filtering (Hazy retry logic)
	if len(hist) == 0 {
		for y := bounds.Min.Y; y < bounds.Max.Y; y += 5 {
			for x := bounds.Min.X; x < bounds.Max.X; x += 5 {
				r16, g16, b16, _ := img.At(x, y).RGBA()
				c := color.RGBA{
					R: uint8(r16 >> 8),
					G: uint8(g16 >> 8),
					B: uint8(b16 >> 8),
					A: 255,
				}
				hist[c]++
			}
		}
	}

	var max int
	var dominant color.RGBA
	for c, count := range hist {
		if count > max {
			max = count
			dominant = c
		}
	}

	return dominant
}

/*
BACKGROUND COLOR
Average + darkened for UI stability
*/
func averageColor(img image.Image) color.RGBA {
	bounds := img.Bounds()
	var rSum, gSum, bSum, count uint64

	for y := bounds.Min.Y; y < bounds.Max.Y; y += 8 {
		for x := bounds.Min.X; x < bounds.Max.X; x += 8 {
			r16, g16, b16, _ := img.At(x, y).RGBA()
			rSum += uint64(r16 >> 8)
			gSum += uint64(g16 >> 8)
			bSum += uint64(b16 >> 8)
			count++
		}
	}

	return color.RGBA{
		R: uint8(rSum / count),
		G: uint8(gSum / count),
		B: uint8(bSum / count),
		A: 255,
	}
}

func main() {
	url, err := getArtworkURL()
	if err != nil || url == "" {
		return
	}

	resp, err := http.Get(url)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	img, _, err := image.Decode(resp.Body)
	if err != nil {
		return
	}

	dominant := dominantColor(img)
	bg := averageColor(img)

	// Tone down background (VERY important for SketchyBar)
	bg = darken(bg, 0.75)

	text := readableTextColor(bg)

	fmt.Printf("BACKGROUND=0xFF%02X%02X%02X\n", bg.R, bg.G, bg.B)
	fmt.Printf("LABEL=0xFF%02X%02X%02X\n", text.R, text.G, text.B)
	fmt.Printf("ICON=0xFF%02X%02X%02X\n", text.R, text.G, text.B)
	fmt.Printf("DOMINANT=0xFF%02X%02X%02X\n", dominant.R, dominant.G, dominant.B)
}
