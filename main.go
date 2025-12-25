package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"sync"
	"time"

	"github.com/eiannone/keyboard"
	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/mem"
	"github.com/shirou/gopsutil/v4/net"
	"github.com/shirou/gopsutil/v4/sensors"
)

const (
	Reset     = "\033[0m"
	Bold      = "\033[1m"
	Underline = "\033[4m"

	Red         = "\033[31m"
	Green       = "\033[32m"
	Yellow      = "\033[33m"
	Blue        = "\033[34m"
	Magenta     = "\033[35m"
	Cyan        = "\033[36m"
	Grey        = "\033[37m"
	ScreenWidth = 36
) // ANSI Formatting

func GetData() (*disk.UsageStat, []cpu.InfoStat, []float64, *mem.VirtualMemoryStat, []net.IOCountersStat, []sensors.TemperatureStat, error) {
	var diskUsage *disk.UsageStat
	var cpuInfo []cpu.InfoStat
	var cpuPercent []float64
	var memoryInfo *mem.VirtualMemoryStat
	var netInfo []net.IOCountersStat
	var temperatures []sensors.TemperatureStat
	var err error

	var wg sync.WaitGroup
	wg.Add(6)

	go func() {
		defer wg.Done()
		diskUsage, _ = disk.Usage("/")
	}()

	go func() {
		defer wg.Done()
		cpuInfo, _ = cpu.Info()
	}()

	go func() {
		defer wg.Done()
		cpuPercent, _ = cpu.Percent(time.Second, false)
	}()

	go func() {
		defer wg.Done()
		memoryInfo, _ = mem.VirtualMemory()
	}()

	go func() {
		defer wg.Done()
		netInfo, _ = net.IOCounters(true)
	}()

	go func() {
		defer wg.Done()
		temperatures, _ = sensors.TemperaturesWithContext(context.Background())
	}()

	wg.Wait()
	return diskUsage, cpuInfo, cpuPercent, memoryInfo, netInfo, temperatures, err
}

func ClearScreen() {
	if runtime.GOOS == "windows" {
		cmd := exec.Command("cmd", "/c", "cls")
		cmd.Stdout = os.Stdout
		err := cmd.Run()
		if err != nil {
			return
		}
	} else {
		cmd := exec.Command("clear")
		cmd.Stdout = os.Stdout
		err := cmd.Run()
		if err != nil {
			return
		}
	}
}

func PrintValue(value string, cursorTop int, cursorLeft int, screenWidth int) {
	fmt.Printf("\033[%d;%dH%s", cursorTop, cursorLeft, value)
}

func PrintMainMenu(diskUsage *disk.UsageStat, cpuInfo []cpu.InfoStat, cpuPercent []float64, memoryInfo *mem.VirtualMemoryStat, netInfo []net.IOCountersStat, tempInfo []sensors.TemperatureStat, err error, BytesRecvDelta float64) {
	if err != nil {
		fmt.Println(err)
	}
	header1 := fmt.Sprintf("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n")
	PrintValue(header1, 1, 0, ScreenWidth)

	header2 := fmt.Sprintf("┃          %s%sSystem Monitor%s          ┃\n", Cyan, Bold, Reset)
	PrintValue(header2, 2, 0, ScreenWidth)

	header3 := fmt.Sprintf("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫\n")
	PrintValue(header3, 3, 0, ScreenWidth)

	padding := 0
	modelLine := ""
	if len(cpuInfo[0].ModelName) > ScreenWidth/2+1 {
		padding = 1
		modelLine = fmt.Sprintf("┃ %s%sCPU Model:   %s%s\n┃              %s",
			Blue, Bold, Reset, cpuInfo[0].ModelName[:ScreenWidth/2], cpuInfo[0].ModelName[ScreenWidth/2:])

		PrintValue(modelLine, 4, 0, ScreenWidth)
		PrintValue("┃", 4, ScreenWidth, ScreenWidth)
		PrintValue("┃", 5, ScreenWidth, ScreenWidth)
	} else {
		modelLine = fmt.Sprintf("┃ %s%sCPU Model:  %s %s", Blue, Bold, Reset, cpuInfo[0].ModelName)
		PrintValue(modelLine, 4, 0, ScreenWidth)
		PrintValue("┃", 4+padding, ScreenWidth, ScreenWidth)
	}

	cpuLine := fmt.Sprintf("┃ %s%sCPU Used:%s    %s [%.2f%%]", Blue, Bold, Reset, GetProgressBar(int(cpuPercent[0]), 10), cpuPercent[0])
	PrintValue(cpuLine, 5+padding, 0, ScreenWidth)
	PrintValue("┃", 5+padding, ScreenWidth, ScreenWidth)

	memLine := fmt.Sprintf("┃ %s%sMemory Used:%s %s [%.2f%%]", Yellow, Bold, Reset, GetProgressBar(int(memoryInfo.UsedPercent), 10), memoryInfo.UsedPercent)
	PrintValue(memLine, 7+padding, 0, ScreenWidth)
	PrintValue("┃", 7+padding, ScreenWidth, ScreenWidth)

	diskLine := fmt.Sprintf("┃ %s%sDisk Used:%s   %s [%.2f%%]", Green, Bold, Reset, GetProgressBar(int(diskUsage.UsedPercent), 10), diskUsage.UsedPercent)
	PrintValue(diskLine, 6+padding, 0, ScreenWidth)
	PrintValue("┃", 6+padding, ScreenWidth, ScreenWidth)

	tempLine := ""
	if len(tempInfo) > 0 {
		tempLine = fmt.Sprintf("┃ %s%sTemps:%s       [%.2f°C]", Red, Bold, Reset, tempInfo[0].Temperature)

	} else {
		tempLine = fmt.Sprintf("┃ %s%sTemps:%s       [N/A]", Red, Bold, Reset)
	}

	PrintValue(tempLine, 8+padding, 0, ScreenWidth)
	PrintValue("┃", 8+padding, ScreenWidth, ScreenWidth)

	prefixes := [6]string{"B", "KiB", "MiB", "GiB", "TiB", "PiB"}
	i := 0
	for i = 0; BytesRecvDelta >= 1024; i++ {
		BytesRecvDelta /= 1024
	}
	netLine := fmt.Sprintf("┃ %s%sNetwork:%s     [%.2f%s]", Magenta, Bold, Reset, BytesRecvDelta, prefixes[i])
	PrintValue(netLine, 9+padding, 0, ScreenWidth)
	PrintValue("┃", 9+padding, ScreenWidth, ScreenWidth)

	PrintValue("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛", 10+padding, 0, ScreenWidth)
	fmt.Printf("\033[%d;0H", 11+padding) // Reset Cursor
}

func PrintNetMenu(netInfo []net.IOCountersStat, selection int, err error) {
	if err != nil {
		fmt.Println(err)
	}

	header1 := fmt.Sprintf("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n")
	PrintValue(header1, 1, ScreenWidth+10, ScreenWidth)

	header2 := fmt.Sprintf("┃           %s%sNetwork Info%s           ┃\n", Magenta, Bold, Reset)
	PrintValue(header2, 2, ScreenWidth+10, ScreenWidth)

	header3 := fmt.Sprintf("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫\n")
	PrintValue(header3, 3, ScreenWidth+10, ScreenWidth)

	connectionsLine := fmt.Sprintf("┃ %s%sConnections:%s [%d]", Magenta, Bold, Reset, len(netInfo))
	PrintValue(connectionsLine, 4, ScreenWidth+10, ScreenWidth)
	PrintValue("┃", 4, ScreenWidth+9+ScreenWidth, ScreenWidth)

	selectionLine := fmt.Sprintf("┃ %s%sSelection:%s   [%d] [<- / ->]", Grey, Bold, Reset, selection)
	PrintValue(selectionLine, 5, ScreenWidth+10, ScreenWidth)
	PrintValue("┃", 5, ScreenWidth+9+ScreenWidth, ScreenWidth)

	header4 := fmt.Sprintf("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫\n")
	PrintValue(header4, 6, ScreenWidth+10, ScreenWidth)

	nameLine := fmt.Sprintf("┃ %s%sName:%s        [%s]", Yellow, Bold, Reset, netInfo[selection].Name)
	PrintValue(nameLine, 7, ScreenWidth+10, ScreenWidth)
	PrintValue("┃", 7, ScreenWidth+9+ScreenWidth, ScreenWidth)

	prefixes := [6]string{"B", "KiB", "MiB", "GiB", "TiB", "PiB"}

	bytesRecv := float64(netInfo[selection].BytesRecv)
	i := 0
	for i = 0; bytesRecv >= 1024 && i < 5; i++ {
		bytesRecv /= 1024
	}
	bytesRecvLine := fmt.Sprintf("┃ %s%sReceived:%s    [%.2f%s]", Cyan, Bold, Reset, bytesRecv, prefixes[i])
	PrintValue(bytesRecvLine, 8, ScreenWidth+10, ScreenWidth)
	PrintValue("┃", 8, ScreenWidth+9+ScreenWidth, ScreenWidth)

	bytesSent := float64(netInfo[selection].BytesSent)
	j := 0
	for j = 0; bytesSent >= 1024 && j < 5; j++ {
		bytesSent /= 1024
	}
	bytesSentLine := fmt.Sprintf("┃ %s%sSent:%s        [%.2f%s]", Cyan, Bold, Reset, bytesSent, prefixes[j])
	PrintValue(bytesSentLine, 9, ScreenWidth+10, ScreenWidth)
	PrintValue("┃", 9, ScreenWidth+9+ScreenWidth, ScreenWidth)

	header5 := fmt.Sprintf("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	PrintValue(header5, 10, ScreenWidth+10, ScreenWidth)

	fmt.Printf("\033[11;0H") // Reset Cursor
}

func GetProgressBar(progress int, base int) string {
	p2 := float64(progress) / 100.0
	p3 := p2 * float64(base)
	progress = int(p3)

	bar := ""
	for i := 0; i < base; i++ {
		if i < progress {
			bar += "█"
		} else {
			bar += "░"
		}
	}
	return bar
}

func ReadKey() (char rune, err error) {
	char, _, err = keyboard.GetKey()
	if err != nil {
		return 0, err
	}
	return char, nil
}

func main() {
	if err := keyboard.Open(); err != nil {
		panic(err)
	}
	defer keyboard.Close()

	selection := 0
	diskUsage, cpuInfo, cpuPercent, memoryInfo, netInfo, temperatureInfo, err := GetData()

	go func() {
		for {
			_, key, err := keyboard.GetKey()
			if err != nil {
				continue
			}

			switch key {
			case keyboard.KeyArrowLeft:
				if selection > 0 {
					selection--
				}
			case keyboard.KeyArrowRight:
				if selection < len(netInfo)-1 {
					selection++
				}
			case keyboard.KeyEsc, keyboard.KeyCtrlC:
				keyboard.Close()
				os.Exit(0)
			}
		}
	}()

	for {
		BytesRecvLastIt := netInfo[0].BytesRecv
		diskUsage, cpuInfo, cpuPercent, memoryInfo, netInfo, temperatureInfo, err = GetData()
		BytesRecvDelta := netInfo[0].BytesRecv - BytesRecvLastIt

		ClearScreen()
		PrintNetMenu(netInfo, selection, err)
		PrintMainMenu(diskUsage, cpuInfo, cpuPercent, memoryInfo, netInfo, temperatureInfo, err, float64(BytesRecvDelta))

		time.Sleep(10 * time.Millisecond)
	}
}
