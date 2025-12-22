package main

import (
	"fmt"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/mem"
)

func main() {
	memUsage, _ := mem.VirtualMemory()
	diskUsage, _ := disk.Usage("/")
	cpuUsage, _ := cpu.Info()

	fmt.Println("CPU: ", cpuUsage)
	fmt.Println("Disk: ", diskUsage)
	fmt.Println("Memory: ", memUsage)
}
