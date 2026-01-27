package main

import (
	"bytes"
	"fmt"
	"image"
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

/*
DOMINANT COLOR
Histogram-based, skips black/white noise
*/
func dominantColor(img image.Image) (uint8, uint8, uint8) {
	bounds := img.Bounds()
	hist := make(map[[3]uint8]int)

	for y := bounds.Min.Y; y < bounds.Max.Y; y += 5 {
		for x := bounds.Min.X; x < bounds.Max.X; x += 5 {
			r16, g16, b16, _ := img.At(x, y).RGBA()
			r := uint8(r16 >> 8)
			g := uint8(g16 >> 8)
			b := uint8(b16 >> 8)

			// Ignore near-black & near-white
			if (r < 15 && g < 15 && b < 15) ||
				(r > 240 && g > 240 && b > 240) {
				continue
			}

			hist[[3]uint8{r, g, b}]++
		}
	}

	var max int
	var color [3]uint8
	for c, count := range hist {
		if count > max {
			max = count
			color = c
		}
	}

	return color[0], color[1], color[2]
}

/*
BACKGROUND COLOR
Simple average = good neutral UI base
*/
func averageColor(img image.Image) (uint8, uint8, uint8) {
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

	return uint8(rSum / count), uint8(gSum / count), uint8(bSum / count)
}

func main() {
	url, err := getArtworkURL()
	if err != nil || url == "" {
		fmt.Println("Spotify not playing")
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

	dr, dg, db := dominantColor(img)
	br, bg, bb := averageColor(img)

	fmt.Printf("DOMINANT=0xFF%02X%02X%02X\n", dr, dg, db)
	fmt.Printf("BACKGROUND=0xFF%02X%02X%02X\n", br, bg, bb)
}
