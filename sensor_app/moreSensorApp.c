#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <string.h>

#define ADC_BASE "/sys/bus/iio/devices/iio:device0/"
#define SCALE_PATH ADC_BASE "in_voltage_scale"

#define CH0 ADC_BASE "in_voltage0_raw"
#define CH1 ADC_BASE "in_voltage1_raw"
#define CH2 ADC_BASE "in_voltage2_raw"   // DHT11占位
#define CH3 ADC_BASE "in_voltage3_raw"

// ================== 数据结构 ==================
typedef struct {
    const char *name;
    const char *pin;

    int raw;
    float voltage;

    float min_v;
    float max_v;

    float last_v;
    int inited;
} Sensor;

// ================== 读取函数 ==================
int read_int(const char *path, int *val)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;

    int ret = fscanf(fp, "%d", val);
    fclose(fp);

    return (ret == 1) ? 0 : -1;
}

int read_float(const char *path, float *val)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;

    int ret = fscanf(fp, "%f", val);
    fclose(fp);

    return (ret == 1) ? 0 : -1;
}

// ================== 状态判断 ==================
const char* light_state(float v)
{
    if (v < 0.8) return "DARK";
    if (v < 2.2) return "NORMAL";
    return "BRIGHT";
}

const char* mq135_state(float v)
{
    if (v < 1.2) return "CLEAN";
    if (v < 1.8) return "MILD POLLUTION";
    return "HEAVY POLLUTION";
}

const char* zp01_state(float v, float last, int inited)
{
    if (!inited) return "INIT";

    float diff = fabs(v - last);

    if (diff < 0.05) return "STABLE";
    if (diff < 0.15) return "FLUCTUATING";
    return "ABNORMAL";
}

// ================== 更新min/max ==================
void update_range(Sensor *s)
{
    if (!s->inited) {
        s->min_v = s->voltage;
        s->max_v = s->voltage;
        s->inited = 1;
        return;
    }

    if (s->voltage < s->min_v)
        s->min_v = s->voltage;

    if (s->voltage > s->max_v)
        s->max_v = s->voltage;
}

// ================== 输出 ==================
void print_sensor(const char *label, Sensor *s, const char *state)
{
    printf("%-6s @ %-5s RAW:%4d  V:%.3f  STATE:%s  [%.3f~%.3f]\n",
           label,
           s->pin,
           s->raw,
           s->voltage,
           state,
           s->min_v,
           s->max_v);
}

// ================== 主程序 ==================
int main()
{
    float scale;

    if (read_float(SCALE_PATH, &scale) != 0 || scale <= 0)
    {
        printf("ERROR: ADC scale read failed\n");
        return -1;
    }

    Sensor light = {"LIGHT", "IO1.0", 0,0,0,0,0,0};
    Sensor zp01  = {"ZP01",  "IO1.1", 0,0,0,0,0,0};
    Sensor dht   = {"DHT11", "GPIO1.2", 0,0,0,0,0,0};
    Sensor mq135 = {"MQ135", "IO1.3", 0,0,0,0,0,0};

    printf("Sensor system started...\n");

    while (1)
    {
        int r0, r1, r2, r3;

        if (read_int(CH0, &r0) != 0 ||
            read_int(CH1, &r1) != 0 ||
            read_int(CH2, &r2) != 0 ||
            read_int(CH3, &r3) != 0)
        {
            printf("ADC read error\n");
            sleep(1);
            continue;
        }

        // 电压换算
        light.raw = r0;
        light.voltage = r0 * scale / 1000.0;

        zp01.raw = r1;
        zp01.voltage = r1 * scale / 1000.0;

        dht.raw = r2;      // GPIO占位
        mq135.raw = r3;
        mq135.voltage = r3 * scale / 1000.0;

        // 状态
        const char *light_s = light_state(light.voltage);
        const char *mq135_s = mq135_state(mq135.voltage);
        const char *zp01_s  = zp01_state(zp01.voltage, zp01.last_v, zp01.inited);

        zp01.last_v = zp01.voltage;

        // 更新范围
        update_range(&light);
        update_range(&zp01);
        update_range(&mq135);

        // 输出
        printf("\n========== SENSOR REPORT ==========\n");

        print_sensor("LIGHT", &light, light_s);
        print_sensor("ZP01",  &zp01,  zp01_s);

        printf("%-6s @ %-5s RAW:%4d  (GPIO SENSOR - DHT11)\n",
               dht.name, dht.pin, dht.raw);

        print_sensor("MQ135", &mq135, mq135_s);

        sleep(1);
    }

    return 0;
}
