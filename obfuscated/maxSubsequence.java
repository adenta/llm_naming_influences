public int[] adfasdf(int[] er34523sdf, int er34sadf523sdf) {
    int esdad23fssfdf = er34523sdf.length;
    int[][] esdadfssf = new int[esdad23fssfdf][2];
    for (int esda234sfdf = 0; esda234sfdf < esdad23fssfdf; ++esda234sfdf) {
        esdadfssf[esda234sfdf] = new int[]{esda234sfdf, er34523sdf[esda234sfdf]};
    }

    Arrays.sort(esdadfssf, Comparator.comparingInt(a -> -a[1]));
    int[][] er34ssdadf523sdf = Arrays.copyOf(esdadfssf, er34sadf523sdf);

    Arrays.sort(er34ssdadf523sdf, Comparator.comparingInt(a -> a[0]));
    int[] esda23ad4sfdf = new int[er34sadf523sdf];
    for (int esda234sfdf = 0; esda234sfdf < er34sadf523sdf; ++esda234sfdf) {
        esda23ad4sfdf[esda234sfdf] = er34ssdadf523sdf[esda234sfdf][1];
    }
    return esda23ad4sfdf;
}
