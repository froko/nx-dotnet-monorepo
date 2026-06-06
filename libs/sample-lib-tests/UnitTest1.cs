namespace SampleLib.Tests;

public class GreeterTests
{
    [Fact]
    public void Greet_ReturnsGreetingWithName()
    {
        var result = Greeter.Greet("World");

        Assert.Equal("Hello, World!", result);
    }
}
