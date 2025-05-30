bool dfs(int i, int j, vector<vector<int>> &grid)
{
    int m = grid.size();
    int n = grid[0].size();
    if (i == m - 1 and j == n - 1)
        return true;
    if (i < 0 or i >= m or j < 0 or j >= n)
        return false;

    if (grid[i][j] == 1)
    {
        grid[i][j] = 0;
        return dfs(i + 1, j, grid) or dfs(i, j + 1, grid);
    }
    else
    {
        return false;
    }
}

bool isPossibleToCutPath(vector<vector<int>> &grid)
{
    int m = grid.size();
    int n = grid[0].size();
    dfs(0, 0, grid);

    grid[0][0] = 1;
    grid[m - 1][n - 1] = 1;
    return !dfs(0, 0, grid);
}